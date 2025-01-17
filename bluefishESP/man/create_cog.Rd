% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/create_cog.R
\name{create_cog}
\alias{create_cog}
\title{Create center of gravity indicators}
\usage{
create_cog(
  data = here::here("../../VAST/neusvast/final/doy2/cog_100.csv"),
  return = TRUE
)
}
\arguments{
\item{data}{Filepath to the indicator data}

\item{return}{Boolean. Whether to return the indicator as an object in the global environment}
}
\value{
Saves R object `relative_condition`, returns relative condition indicators
}
\description{
This function creates center of gravity indicators from VAST results
}
