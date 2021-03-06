% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/CoxModel.R
\name{setCoxModel}
\alias{setCoxModel}
\title{Create setting for lasso Cox model}
\usage{
setCoxModel(variance = 0.01, seed = NULL)
}
\arguments{
\item{variance}{a single value used as the starting value for the automatic lambda search}

\item{seed}{An option to add a seed when training the model}
}
\description{
Create setting for lasso Cox model
}
\examples{
model.lr <- setCoxModel()
}
