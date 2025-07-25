% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/loadByProduct.R
\name{loadByProduct}
\alias{loadByProduct}
\title{Get files from NEON API, stack tables, and load into the current environment}
\usage{
loadByProduct(
  dpID,
  site = "all",
  startdate = NA,
  enddate = NA,
  package = "basic",
  release = "current",
  timeIndex = "all",
  tabl = "all",
  cloud.mode = FALSE,
  check.size = TRUE,
  include.provisional = FALSE,
  nCores = 1,
  forceParallel = FALSE,
  token = NA_character_,
  useFasttime = FALSE,
  avg = NA,
  progress = TRUE
)
}
\arguments{
\item{dpID}{The identifier of the NEON data product to pull, in the form DPL.PRNUM.REV, e.g. DP1.10023.001}

\item{site}{Either the string 'all', meaning all available sites, or a character vector of 4-letter NEON site codes, e.g. c('ONAQ','RMNP'). Defaults to all.}

\item{startdate}{Either NA, meaning all available dates, or a character vector in the form YYYY-MM, e.g. 2017-01. Defaults to NA.}

\item{enddate}{Either NA, meaning all available dates, or a character vector in the form YYYY-MM, e.g. 2017-01. Defaults to NA.}

\item{package}{Either 'basic' or 'expanded', indicating which data package to download. Defaults to basic.}

\item{release}{The data release to be downloaded; either 'current' or the name of a release, e.g. 'RELEASE-2021'. 'current' returns the most recent release, as well as provisional data if include.provisional is set to TRUE. To download only provisional data, use release='PROVISIONAL'. Defaults to 'current'.}

\item{timeIndex}{Either the string 'all', or the time index of data to download, in minutes. Only applicable to sensor (IS) data. Defaults to 'all'.}

\item{tabl}{Either the string 'all', or the name of a single data table to download. Defaults to 'all'.}

\item{cloud.mode}{T or F, are files transferred cloud-to-cloud? Defaults to F; set to true only if the destination location (where you are downloading the files to) is in the cloud.}

\item{check.size}{T or F, should the user approve the total file size before downloading? Defaults to T. When working in batch mode, or other non-interactive workflow, use check.size=F.}

\item{include.provisional}{T or F, should provisional data be included in downloaded files? Defaults to F. See https://www.neonscience.org/data-samples/data-management/data-revisions-releases for details on the difference between provisional and released data.}

\item{nCores}{The number of cores to parallelize the stacking procedure. By default it is set to a single core.}

\item{forceParallel}{If the data volume to be processed does not meet minimum requirements to run in parallel, this overrides. Set to FALSE as default.}

\item{token}{User specific API token (generated within data.neonscience.org user accounts)}

\item{useFasttime}{Should the fasttime package be used to read date-time fields? Defaults to false.}

\item{avg}{Deprecated; use timeIndex}

\item{progress}{T or F, should progress bars be printed? Defaults to TRUE.}
}
\value{
A named list of all the data tables in the data product downloaded, plus a validation file and a variables file, as available.
}
\description{
Pull files from the NEON API, by data product, merge data for each table, and read into the current R environment
}
\details{
All available data meeting the query criteria will be downloaded. Most data products are collected at only a subset of sites, and dates of collection vary. Consult the NEON data portal for sampling details.
Dates are specified only to the month because NEON data are provided in monthly packages. Any month included in the search criteria will be included in the download. Start and end date are inclusive.
}
\examples{
\dontrun{
# To download plant foliar properties data from all sites, expanded data package:
cfc <- loadByProduct(dpID="DP1.10026.001", site="all", package="expanded")
}
}
\references{
License: GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
}
\author{
Claire Lunch \email{clunch@battelleecology.org}
}
