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
library (Cairo)  #  For transparency
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

"Usage:  fastq-qscores-summary.R --filename FNAME --input INPUT --output OUTPUT

Options:
  --filename FNAME  Name of the input file
  --input INPUT  Path to input file
  --output OUTPUT  Path to output file

.
" -> options

# Retrieve the command-line arguments
opts <- docopt (options)

FNAME_ARG <- opts$filename
INPUT_ARG <- opts$input
OUTPUT_ARG <- opts$output


######################################################################
##  Read in the two data sets (i.e., with the sample names separated) and then melt it down
######################################################################

fn <- INPUT_ARG
x <- read.table (file=fn, sep="\t", header=FALSE)
colnames (x) <- c("qscores", "frequency")
x$qscores <- x$qscores - 33
total_count <- sum (x$frequency)
x$proportion <- (x$frequency / sum (x$frequency))

#  Take all the non-zero values
x <- x[x$frequency > 0,]


######################################################################
##  Plot the histogram plots
######################################################################

#  Build the ggplot object
ggplot_obj <- ggplot (x, aes (x=qscores, y=proportion))
ggplot_obj <- ggplot_obj + geom_bar (stat = "identity")

#  Add axes labels to graph
ggplot_obj <- ggplot_obj + xlab ("Quality scores") + ylab ("Proportion")

#  Add a title
ggplot_obj <- ggplot_obj + ggtitle (FNAME_ARG)


######################################################################
##  Save the graph
######################################################################

#  Set up the output file, using CairoPS so that we can have transparency
out_fn <- OUTPUT_ARG
ggsave (out_fn, plot=ggplot_obj, device=cairo_ps, width = FIGURE_WIDTH, height = FIGURE_HEIGHT, dpi = FIGURE_DPI, units = "cm")


