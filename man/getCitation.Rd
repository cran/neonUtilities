% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getCitation.R
\name{getCitation}
\alias{getCitation}
\title{Get a Bibtex citation for NEON data with a DOI, or generate a provisional Bibtex citation}
\usage{
getCitation(dpID = NA_character_, release = NA_character_)
}
\arguments{
\item{dpID}{The data product ID of the data to be cited [character]}

\item{release}{The data release to be cited. Can be provisional. [character]}
}
\value{
A character string containing the Bibtex citation
}
\description{
Use the DOI Foundation API to get Bibtex-formatted citations for NEON data, or use a template to generate a Bibtex citation for provisional data. Helper function to download and stacking functions.
}
\examples{
\dontrun{
# Get the citation for Breeding landbird point counts (DP1.10003.001), RELEASE-2023
cit <- getCitation(dpID="DP1.10003.001", release="RELEASE-2023")
}
}
\references{
License: GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
}
\author{
Claire Lunch \email{clunch@battelleecology.org}
}
