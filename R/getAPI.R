##############################################################################################
#' @title Get the data from API

#' @author
#' Nate Mietkiewicz \email{mietkiewicz@battelleecology.org}

#' @description Accesses the API with options to use the user-specific API token generated within data.neonscience.org user accounts.
#'
#' @keywords internal
#' @param apiURL The API endpoint URL
#' @param token User specific API token (generated within data.neonscience.org user accounts). Optional.

#' @references
#' License: GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007

# Changelog and author contributions / copyrights
#   2020-05-21 (Claire Lunch): Modified to check for reaching rate limit
#   2020-03-21 (Nate Mietkiewicz): Created original function
##############################################################################################

getAPI <- function(apiURL, token=NA_character_){

  if(!curl::has_internet()) {
    message("No internet connection detected. Cannot access NEON API.")
    return(invisible())
  }
  
  if(identical(token, "")) {token <- NA_character_}
  
  usera <- paste("neonUtilities/", utils::packageVersion("neonUtilities"), " R/", 
                 R.Version()$major, ".", R.Version()$minor, " ", commandArgs()[1], 
                 " ", R.Version()$platform, sep="")
  
  if(is.na(token)) {
    
    # make 5 attempts to access - if rate limit is reached every time, give up
    j <- 1
    while(j < 6) {

      req <- try(httr::GET(apiURL, httr::user_agent(usera)), silent=T)
      
      # check for no response
      if(!inherits(req, "response")) {
        message("No response. NEON API may be unavailable, check NEON data portal for outage alerts. If the problem persists and can't be traced to an outage alert, check your computer for firewall or other security settings preventing R from accessing the internet.")
        return(invisible())
      }
      
      # if rate limit is reached, pause
      if(!is.null(req$headers$`x-ratelimit-limit`)) {
        
        if(req$headers$`x-ratelimit-remaining`<=1) {
          message(paste("Rate limit reached. Pausing for ", 
                    req$headers$`x-ratelimit-reset`,
                    " seconds to reset. For faster downloads, use a NEON user account and API token. Instructions here: https://www.neonscience.org/resources/learning-hub/tutorials/neon-api-tokens-tutorial", 
                    sep=""))
          Sys.sleep(req$headers$`x-ratelimit-reset`)
          j <- j+1
        } else {
          j <- j+5
        }
      } else {
        j <- j+5
      }
    }

  } else {
    
    # same process as in non-token case: make 5 attempts
    
    j <- 1
    while(j < 6) {

      req <- try(httr::GET(apiURL, httr::user_agent(usera),
                       httr::add_headers(.headers = c('X-API-Token'= token,
                                                      'accept' = 'application/json'))),
                 silent=T)
      
      # check for no response
      if(!inherits(req, "response")) {
        message("No response. NEON API may be unavailable, check NEON data portal for outage alerts. If the problem persists and can't be traced to an outage alert, check your computer for firewall or other security settings preventing R from accessing the internet.")
        return(invisible())
      }

      # first check for null, since unlimited tokens don't have these headers
      if(!is.null(req$headers$`x-ratelimit-limit`)) {

        # if rate limit is reached, pause
        if(req$headers$`x-ratelimit-remaining`<=1) {
          message(paste("Rate limit reached. Pausing for ", 
                    req$headers$`x-ratelimit-reset`,
                    " seconds to reset.", sep=""))
          Sys.sleep(req$headers$`x-ratelimit-reset`)
          j <- j+1
        } else {
          j <- j+5
        }
      } else {
        j <- j+5
      }
    }
  }

  return(req)

}
