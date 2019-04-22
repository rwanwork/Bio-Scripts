#!/usr/bin/env Rscript
#####################################################################
##
##  Plot histogram of the quality scores
##
#####################################################################

##############################
##  Read in libraries and modules

#  Load in libraries
library (ggplot2)
library (scales)  #  trans_breaks and trans_format
# library (Cairo)  #  For transparency
library (docopt)  #  See:  https://github.com/docopt/docopt.R


#####################################################################
##  Setup constants
#####################################################################

FIGURE_WIDTH <- 20
FIGURE_HEIGHT <- 12
FIGURE_DPI <- 600


#####################################################################
##  Process arguments using docopt
#####################################################################

"Usage:  fastq-readlen-summary.R --filename FNAME --input INPUT --output OUTPUT --xlimit XLIMIT

Options:
  --filename FNAME  Name of the input file
  --input INPUT  Path to input file
  --output OUTPUT  Path to output file
  --xlimit XLIMIT  Add an x-limit

.
" -> options

# Retrieve the command-line arguments
opts <- docopt (options)

FNAME_ARG <- opts$filename
INPUT_ARG <- opts$input
OUTPUT_ARG <- opts$output
XLIMIT_ARG <- as.numeric (opts$xlimit)


######################################################################
##  Read in the two data sets (i.e., with the sample names separated) and then melt it down
######################################################################

fn <- INPUT_ARG
x <- read.table (file=fn, sep="\t", header=FALSE)
colnames (x) <- c("values")
x$values <- as.numeric (x$values)


######################################################################
##  Plot the histogram plots
######################################################################

#  Build the ggplot object
ggplot_obj <- ggplot (x, aes(x = values))
ggplot_obj <- ggplot_obj + geom_histogram (aes (y=..count../sum(..count..)), bins = 32, position="identity")

#  Add axes labels to graph
ggplot_obj <- ggplot_obj + xlab ("Read lengths") + ylab ("Proportion")

#  Add a title
ggplot_obj <- ggplot_obj + ggtitle (FNAME_ARG)

#  Set x limit
ggplot_obj <- ggplot_obj + xlim (0, XLIMIT_ARG)
# ggplot_obj <- ggplot_obj + scale_x_continuous (limits = c(0, XLIMIT_ARG))


######################################################################
##  Save the graph
######################################################################

#  Set up the output file, using CairoPS so that we can have transparency
out_fn <- OUTPUT_ARG
# ggsave (file=out_fn, plot=ggplot_obj, device="eps", width = FIGURE_WIDTH, height = FIGURE_HEIGHT, dpi = FIGURE_DPI, units = "cm")

postscript (file = out_fn, width = FIGURE_WIDTH, height = FIGURE_HEIGHT)
hist (x$values, xlim = c(0, XLIMIT_ARG), breaks=128, probability=TRUE, xlab="Read lengths", main=FNAME_ARG)
dev.off ()

