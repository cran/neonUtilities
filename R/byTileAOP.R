##############################################################################################
#' @title Download AOP tiles overlapping specified coordinates for a given site, year, and product

#' @author
#' Claire Lunch \email{clunch@battelleecology.org}
#' Christine Laney \email{claney@battelleecology.org}

#' @description
#' Query the API for AOP data by site, year, product, and tile location, and download all files found.
#' Downloads serially to avoid overload; may take a very long time.
#'
#' @param dpID The identifier of the NEON data product to pull, in the form DPL.PRNUM.REV, e.g. DP1.10023.001
#' @param site The four-letter code of a single NEON site, e.g. 'CLBJ'.
#' @param year The four-digit year to search for data. Defaults to 2017.
#' @param easting A vector containing the easting UTM coordinates of the locations to download.
#' @param northing A vector containing the northing UTM coordinates of the locations to download.
#' @param buffer Size, in meters, of the buffer to be included around the coordinates when determining which tiles to download. Defaults to 0. If easting and northing coordinates are the centroids of NEON TOS plots, use buffer=20.
#' @param include.provisional T or F, should provisional data be included in downloaded files? Defaults to F. See https://www.neonscience.org/data-samples/data-management/data-revisions-releases for details on the difference between provisional and released data.
#' @param check.size T or F, should the user approve the total file size before downloading? Defaults to T. When working in batch mode, or other non-interactive workflow, use check.size=F.
#' @param savepath The file path to download to. Defaults to NA, in which case the working directory is used.
#' @param token User specific API token (generated within data.neonscience.org user accounts)
#' @param progress T or F, should progress bars be printed? Defaults to TRUE.

#' @return A folder in the working directory, containing all files meeting query criteria.

#' @references
#' License: GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007

#' @export

# Changelog and author contributions / copyrights
#   Claire Lunch (2018-02-19): original creation
#   Christine Laney (2018-03-05): Added functionality to get new list of URLs if the old ones expire, during the download stream.
#   Claire Lunch (2023-05-05): Modified UTM conversion at BLAN to use sf and terra packages instead of sp and raster

##############################################################################################

byTileAOP <- function(dpID, site, year, easting, northing, buffer=0,
                      include.provisional=FALSE, check.size=TRUE, 
                      savepath=NA, token=NA_character_,
                      progress=TRUE) {

  # error message if dpID isn't formatted as expected
  if(regexpr("DP[1-4]{1}.[0-9]{5}.00[1-2]{1}",dpID)!=1) {
    stop(paste(dpID, "is not a properly formatted data product ID. The correct format is DP#.#####.00#", sep=" "))
  }

  # error message if dpID isn't a Level 3 product
  if(substring(dpID, 3, 3)!=3 & dpID!="DP1.30003.001") {
    stop(paste(dpID, "is not a Level 3 data product ID.\nThis function will only work correctly on mosaicked data.", sep=" "))
  }

  # error message if site is left blank
  if(regexpr('[[:alpha:]]{4}', site)!=1) {
    stop("A four-letter site code is required. NEON sites codes can be found here: https://www.neonscience.org/field-sites/field-sites-map/list")
  }

  # error message if year is left blank
  if(regexpr('[[:digit:]]{4}', year)!=1) {
    stop("Year is required (e.g. '2017').")
  }

  # error message if easting and northing vector lengths don't match
  easting <- as.numeric(easting)
  northing <- as.numeric(northing)
  easting <- easting[which(!is.na(easting) & !is.null(easting) & easting!="")]
  northing <- northing[which(!is.na(northing) & !is.null(northing) & northing!="")]
  if(length(easting)!=length(northing)) {
    stop("Easting and northing vector lengths do not match, and/or contain null values. Cannot identify paired coordinates.")
  }

  # error message if buffer is bigger than a tile
  if(buffer>=1000) {
    stop("Buffer is larger than tile size. Tiles are 1x1 km.")
  }
  
  # if token is an empty string, set to NA
  if(identical(token, "")) {token <- NA_character_}
  
  # check for token expiration
  token <- tokenCheck(token)
  
  releases <- character()

  # query the products endpoint for the product requested
  prod.req <- getAPI(apiURL = paste("https://data.neonscience.org/api/v0/products/", dpID, sep=""), 
                  token = token)
  
  avail <- jsonlite::fromJSON(httr::content(prod.req, as='text', encoding='UTF-8'), 
                              simplifyDataFrame=TRUE, flatten=TRUE)

  # error message if product not found
  if(!is.null(avail$error$status)) {
    stop(paste("No data found for product", dpID, sep=" "))
  }
  
  # check that token was used
  if(!is.na(token) & !is.null(prod.req$headers$`x-ratelimit-limit`)) {
    if(prod.req$headers$`x-ratelimit-limit`==200) {
      message('API token was not recognized. Public rate limit applied.')
    }
  }

  # error message if data are not from AOP
  if(avail$data$productScienceTeamAbbr!="AOP") {
    stop(paste(dpID, "is not a remote sensing product. Use zipsByProduct()"))
  }

  # check for sites that are flown under the flight box of a different site
  if(site %in% shared_flights$site) {
    flightSite <- shared_flights$flightSite[which(shared_flights$site==site)]
    if(site %in% c('TREE','CHEQ','KONA','DCFS')) {
      message(paste(site, ' is part of the flight box for ', flightSite,
                '. Downloading data from ', flightSite, '.\n', sep=''))
    } else {
      message(paste(site, ' is an aquatic site and is sometimes included in the flight box for ', flightSite,
                '. Aquatic sites are not always included in flight coverage every year.\nDownloading data from ',
                flightSite, '. Check data to confirm coverage of ', site, '.\n', sep=''))
    }
    site <- flightSite
  }

  # get the urls for months with data available, and subset to site
  month.urls <- unlist(avail$data$siteCodes$availableDataUrls)
  month.urls <- month.urls[grep(paste(site, year, sep="/"), month.urls)]

  # error message if nothing is available
  if(length(month.urls)==0) {
    stop("There are no data at the selected site and year.")
  }

  # convert easting & northing coordinates for Blandy (BLAN)
  # Blandy contains plots in 18N and plots in 17N; flight data are all in 17N
  if(site=='BLAN' & length(which(easting<=250000))>0) {
    
    # check for spatial packages
    if(!requireNamespace("terra", quietly=T)) {
      stop("Package terra is required for this function to work at the BLAN site. Install and re-try.")
    }
    
    easting17 <- easting[which(easting>250000)]
    northing17 <- northing[which(easting>250000)]

    easting18 <- easting[which(easting<=250000)]
    northing18 <- northing[which(easting<=250000)]

    df18 <- cbind(easting18, northing18)
    colnames(df18) <- c("easting","northing")

    epsg.z <- relevant_EPSG$code[grep("+proj=utm +zone=17", 
                                      relevant_EPSG$prj4, fixed=T)]

    df18 <- terra::vect(df18, crs="+proj=utm +zone=18")
    df18conv <- terra::project(df18, y=paste("EPSG:", epsg.z, sep=""))
    df18coords <- data.frame(terra::crds(df18conv))
    
    easting <- c(easting17, df18coords$x)
    northing <- c(northing17, df18coords$y)

    message('Blandy (BLAN) plots include two UTM zones, flight data are all in 17N.
        Coordinates in UTM zone 18N have been converted to 17N to download the correct tiles.
        You will need to make the same conversion to connect airborne to ground data.')
  }

  # get the tile corners for the coordinates
  tileEasting <- floor(easting/1000)*1000
  tileNorthing <- floor(northing/1000)*1000

  # apply buffer
  if(buffer>0) {

    # add & subtract buffer (buffer is a square)
    eastingPlus <- floor((easting + buffer)/1000)*1000
    eastingMinus <- floor((easting - buffer)/1000)*1000
    northingPlus <- floor((northing + buffer)/1000)*1000
    northingMinus <- floor((northing - buffer)/1000)*1000

    # get coordinates where buffer overlaps another tile
    eastingPlusMatch <- tileEasting==eastingPlus
    eastingMinusMatch <- tileEasting==eastingMinus
    northingPlusMatch <- tileNorthing==northingPlus
    northingMinusMatch <- tileNorthing==northingMinus
    matchMat <- cbind(eastingMinusMatch, eastingPlusMatch, northingMinusMatch, northingPlusMatch)
    matchMat <- 1*matchMat

    # add coordinates for overlapping tiles
    for(k in 1:length(easting)) {
      pos <- paste0(matchMat[k,], collapse=".")
      if(pos=="1.1.1.1") {
        next
      } else {
        if(pos=="0.1.1.1") {
          tileEasting <- c(tileEasting, eastingMinus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
        }
        if(pos=="1.0.1.1") {
          tileEasting <- c(tileEasting, eastingPlus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
        }
        if(pos=="0.1.0.1") {
          tileEasting <- c(tileEasting, eastingMinus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
          tileEasting <- c(tileEasting, eastingMinus[k])
          tileNorthing <- c(tileNorthing, northingMinus[k])
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingMinus[k])
        }
        if(pos=="0.1.1.0") {
          tileEasting <- c(tileEasting, eastingMinus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
          tileEasting <- c(tileEasting, eastingMinus[k])
          tileNorthing <- c(tileNorthing, northingPlus[k])
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingPlus[k])
        }
        if(pos=="1.0.0.1") {
          tileEasting <- c(tileEasting, eastingPlus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
          tileEasting <- c(tileEasting, eastingPlus[k])
          tileNorthing <- c(tileNorthing, northingMinus[k])
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingMinus[k])
        }
        if(pos=="1.0.1.0") {
          tileEasting <- c(tileEasting, eastingPlus[k])
          tileNorthing <- c(tileNorthing, tileNorthing[k])
          tileEasting <- c(tileEasting, eastingPlus[k])
          tileNorthing <- c(tileNorthing, northingPlus[k])
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingPlus[k])
        }
        if(pos=="1.1.0.1") {
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingMinus[k])
        }
        if(pos=="1.1.1.0") {
          tileEasting <- c(tileEasting, tileEasting[k])
          tileNorthing <- c(tileNorthing, northingPlus[k])
        }
      }
    }
  }

  file.urls.current <- getTileUrls(month.urls,
                                   include.provisional=include.provisional,
                                   format(tileEasting, scientific=F, justified='none'),
                                   format(tileNorthing, scientific=F, justified='none'))
  if(is.null(file.urls.current[[1]])) {
    message("No data files found.")
    return(invisible())
  }
  downld.size <- sum(as.numeric(as.character(file.urls.current[[1]]$size)), na.rm=T)
  downld.size.read <- convByteSize(downld.size)

  # ask user if they want to proceed
  # can disable this with check.size=F
  if(check.size==TRUE) {
    resp <- readline(paste("Continuing will download ", nrow(file.urls.current[[1]]), " files totaling approximately ",
                           downld.size.read, ". Do you want to proceed y/n: ", sep=""))
    if(!(resp %in% c("y","Y"))) {
      stop("Download halted.")
    }
  } else {
    if(isTRUE(progress)) {
      message(paste("Downloading files totaling approximately", downld.size.read, "\n", sep=" "))
    }
    }

  # create folder in working directory to put files in
  if(is.na(savepath)) {
    filepath <- paste(getwd(), "/", dpID, sep="")
  } else {
    filepath <- paste(savepath, "/", dpID, sep="")
  }
  if(dir.exists(filepath) == F) {dir.create(filepath, showWarnings=F)}

  # set user agent
  usera <- paste("neonUtilities/", utils::packageVersion("neonUtilities"), " R/", 
                 R.Version()$major, ".", R.Version()$minor, " ", commandArgs()[1], 
                 " ", R.Version()$platform, sep="")
  
  # copy zip files into folder
  j <- 1
  if(isTRUE(progress)) {
    message(paste("Downloading ", nrow(file.urls.current[[1]]), " files", sep=""))
    pb <- utils::txtProgressBar(style=3)
    utils::setTxtProgressBar(pb, 1/(nrow(file.urls.current[[1]])-1))
  }

  counter <- 1

  while(j <= nrow(file.urls.current[[1]])) {

    if (counter > 2) {
      message(paste0("\nRefresh did not solve the isse. URL query for file ", file.urls.current[[1]]$name[j],
                  " failed. If all files fail, check data portal (data.neonscience.org/news) for possible outage alert.\n",
                 "If file sizes are large, increase the timeout limit on your machine: options(timeout=###)"))

      j <- j + 1
      counter <- 1
    } else {
      path1 <- strsplit(file.urls.current[[1]]$URL[j], "\\?")[[1]][1]
      pathparts <- strsplit(path1, "\\/")
      path2 <- paste(pathparts[[1]][4:(length(pathparts[[1]])-1)], collapse="/")
      newpath <- paste0(filepath, "/", path2)

      if(dir.exists(newpath) == FALSE) {
        dir.create(newpath, recursive = TRUE)
      }

      if(is.na(token)) {
        t <- tryCatch(
          {
            suppressWarnings(downloader::download(file.urls.current[[1]]$URL[j],
                                                  paste(newpath, file.urls.current[[1]]$name[j], sep="/"),
                                                  mode="wb", quiet=T,
                                                  headers=c("User-Agent"=usera)))
          }, error = function(e) { e } )
      } else {
        t <- tryCatch(
          {
            suppressWarnings(downloader::download(file.urls.current[[1]]$URL[j],
                                                  paste(newpath, file.urls.current[[1]]$name[j], sep="/"),
                                                  mode="wb", quiet=T,
                                                  headers=c("User-Agent"=usera,
                                                            "X-API-Token"=token)))
          }, error = function(e) { e } )
      }

      if(inherits(t, "error")) {
        
        # re-attempt download once with no changes
        if(counter < 2) {
          message(paste0("\n", file.urls.current[[1]]$name[j], " could not be downloaded. Re-attempting."))
          t <- tryCatch(
            {
              suppressWarnings(downloader::download(file.urls.current[[1]]$URL[j],
                                                    paste(newpath, file.urls.current[[1]]$name[j], sep="/"),
                                                    mode="wb", quiet=T,
                                                    headers=c("User-Agent"=usera)))
            }, error = function(e) { e } )
          if(inherits(t, "error")) {
            counter <- counter + 1
          } else {
            #message(paste(file.urls.current[[1]]$name[j], "downloaded to", newpath, sep=" "))
            j <- j + 1
            counter <- 1
          }
        } else {
          message(paste0("\n", file.urls.current[[1]]$name[j], " could not be downloaded. URLs may have expired. Refreshing URL list."))
          file.urls.new <- getTileUrls(month.urls, tileEasting, tileNorthing, 
                                       include.provisional=include.provisional, token=token)
          file.urls.current <- file.urls.new
          counter <- counter + 1
        }
        
      } else {
        #message(paste(file.urls.current[[1]]$name[j], "downloaded to", newpath, sep=" "))
        j <- j + 1
        counter <- 1
        releases <- c(releases, file.urls.current[[2]])
        
        if(isTRUE(progress)) {
          utils::setTxtProgressBar(pb, j/(nrow(file.urls.current[[1]])-1))
        }
        
      }

    }
  }
  if(isTRUE(progress)) {
    utils::setTxtProgressBar(pb, 1)
    close(pb)
  }
  
  # get issue log and write to file
  issues <- getIssueLog(dpID=dpID, token=token)
  utils::write.csv(issues, paste0(filepath, "/issueLog_", dpID, ".csv"),
                   row.names=FALSE)
  
  # get DOIs and generate citation(s)
  releases <- unique(releases)
  if("PROVISIONAL" %in% releases) {
    cit <- try(getCitation(dpID=dpID, release="PROVISIONAL"), silent=TRUE)
    if(!inherits(cit, "try-error")) {
      base::write(cit, paste0(filepath, "/citation_", dpID, "_PROVISIONAL", ".txt"))
    }
  }
  if(length(grep("RELEASE", releases))==0) {
    releases <- releases
  } else {
    if(length(grep("RELEASE", releases))==1) {
      rel <- releases[grep("RELEASE", releases)]
      cit <- try(getCitation(dpID=dpID, release=rel), silent=TRUE)
      if(!inherits(cit, "try-error")) {
        base::write(cit, paste0(filepath, "/citation_", dpID, "_", rel, ".txt"))
      }
    }
  }

  # add a counter instead of using starting number
  if(isTRUE(progress)) {
    message(paste("Successfully downloaded ", nrow(file.urls.current[[1]]), " files to ", filepath, sep=""))
  }
  
}
