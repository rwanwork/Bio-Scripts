#!/usr/bin/env perl
#  Author:  Raymond Wan
#  Copyright (C) 2010-2019, Raymond Wan, All rights reserved.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


use FindBin qw ($Bin);
use lib "$Bin";

use diagnostics;
use strict;
use warnings;

use AppConfig;
use AppConfig::Getopt;
use Pod::Usage;


########################################
##  Constants
########################################

my $MAX_ASCII = 256;


########################################
##  Important variables
########################################

##  Input arguments
my $dlengths_fn_arg = "";
my $dqscores_fn_arg = "";
my $nonewline_arg = 0;
my $input_fn_arg = "";

##  Arrays to keep track of distributions
my @seq_lengths;
my @qscores_acc;

##  Squared difference of sequence lengths, for calculating the standard deviation
my @squared_diff;

##  Standard deviation
my $stddev = 0;


########################################
##  Process arguments
########################################

##  Create AppConfig and AppConfig::Getopt objects
my $config = AppConfig -> new ({
        GLOBAL => {
            DEFAULT => undef,     ##  Default value for new variables
        }
    });

my $getopt = AppConfig::Getopt -> new ($config);

$config -> define ("dlengths", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
        });                            ##  Distribution of lengths
$config -> define ("dqscores", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
        });                            ##  Distribution of quality scores
$config -> define ("nonewline!", {
            DEFAULT => 0,
        });                            ##  Remove newline
$config -> define ("summary!", {
            DEFAULT => 0,
        });                            ##  Summary output
$config -> define ("verbose!", {
            DEFAULT => 0,
        });                            ##  Verbose output
$config -> define ("help!", {
            DEFAULT => 0,
        });                            ##  Help screen

##  Process the command-line options
$config -> getopt ();


########################################
##  Validate the settings
########################################

if ($config -> get ("help")) {
  pod2usage (-verbose => 0);
  exit (1);
}

if ($config -> get ("nonewline")) {
  $nonewline_arg = 1;
}

my $dlen_fp;
if (defined ($config -> get ("dlengths"))) {
  $dlengths_fn_arg = $config -> get ("dlengths");
  open ($dlen_fp, ">", $dlengths_fn_arg) or die "EE\tCould not create $dlengths_fn_arg";
}

my $dqs_fp;
if (defined ($config -> get ("dqscores"))) {
  if ($nonewline_arg == 0) {
    printf STDERR "EE\tThe --nonewline argument must be used if the distribution of quality scores is desired.\n";
    exit (1);
  }
  $dqscores_fn_arg = $config -> get ("dqscores");
  
  for (my $k = 0; $k < $MAX_ASCII; $k++) {
    $qscores_acc[$k] = 0;
  }
  
  open ($dqs_fp, ">", $dqscores_fn_arg) or die "EE\tCould not create $dqscores_fn_arg";
}


########################################
##  Main program body
########################################

my $min_read_length = 0;
my $max_read_length = 0;
my $avg_read_length = 0;
my $num_reads = 0;

my $id1_size = 0;
my $seq_size = 0;
my $id2_size = 0;
my $qs_size = 0;
my $total_size = 0;

my $min_qs_value = $MAX_ASCII;
my $max_qs_value = 0;

while (<STDIN>) {
  my $id1 = $_;
  my $seq = <STDIN>;
  my $id2 = <STDIN>;
  my $qs = <STDIN>;

  ##  Remove newline character
  if ($nonewline_arg == 1) {
    chomp ($id1);
    chomp ($seq);
    chomp ($id2);
    chomp ($qs);
  }
  
  ##  Verify the sequence and quality scores lengths
  if (length ($seq) != length ($qs)) {
    printf STDERR "EE\tLength of the sequence and the quality scores do not match!\n";
    printf STDERR "EE\t[%s]\n", $seq;
    exit (1);
  }
  
  ##  Verify the two identifiers $id1 and $id2
  if ($id1 !~ /^@/) {
    chomp ($id1);
    printf STDERR "EE\tInvalid header line!\n";
    printf STDERR "EE\t[%s]\n", $id1;
    exit (1);
  }
  if ($id2 !~ /^\+/) {
    chomp ($id2);
    printf STDERR "EE\tInvalid second header line!\n";
    printf STDERR "EE\t[%s]\n", $id2;
    exit (1);
  }

  $id1_size += length ($id1);
  $seq_size += length ($seq);
  $id2_size += length ($id2);
  $qs_size += length ($qs);

  ##  If requested, print out the distribution of quality scores to file
  if (defined ($config -> get ("dqscores"))) {
    my @tmp_qs = split //, $qs;
    for (my $k = 0; $k < scalar (@tmp_qs); $k++) {
      my $value = ord ($tmp_qs[$k]);
  
      ##  Ignore newline character
      if (($value != 10) && ($value < $min_qs_value)) {
        $min_qs_value = $value;
      }
      if ($value > $max_qs_value) {
        $max_qs_value = $value;
      }
    
      $qscores_acc[$value]++;
    }
  }

  my $curr_seq_length = length ($seq);
  push (@seq_lengths, $curr_seq_length);

  ##  Determine the minimum and maximum read lengths
  if ($max_read_length == 0) {
    $min_read_length = $curr_seq_length;
    $max_read_length = $curr_seq_length;
  }
  else {
    if ($curr_seq_length < $min_read_length) {
      $min_read_length = $curr_seq_length;
    }
    if ($curr_seq_length > $max_read_length) {
      $max_read_length = $curr_seq_length;
    }
  }

  ##  Used to calculate the average read length
  $avg_read_length += $curr_seq_length;
  
  $num_reads++;
}

if ($num_reads <= 1) {
  printf STDERR "EE\tAt least 2 reads are required for input since the standard deviation is calculated.\n";
  exit (1);
}

$avg_read_length = $avg_read_length / $num_reads;
$total_size = $id1_size + $seq_size + $id2_size + $qs_size;


########################################
##  Calculate the standard deviation
for (my $i = 0; $i < scalar (@seq_lengths); $i++) {
  my $tmp = $seq_lengths[$i];
  $squared_diff[$i] = ($tmp - $avg_read_length) * ($tmp - $avg_read_length);
}

my $sum_squared_diff = 0;
for (my $i = 0; $i < scalar (@squared_diff); $i++) {
  $sum_squared_diff += $squared_diff[$i];
}
$stddev = sqrt ($sum_squared_diff / ($num_reads - 1));


########################################
##  Determine the quality scores type
my $qs_type = "Unknown";
if (defined ($config -> get ("dqscores"))) {
  if (($min_qs_value >= 59) && ($max_qs_value <= 126)) {
    $qs_type = "Solexa";
  }
  elsif (($min_qs_value >= 67) && ($max_qs_value <= 126)) {
    $qs_type = "Illumina 1.5+";
  }
  elsif (($min_qs_value >= 64) && ($max_qs_value <= 126)) {
    $qs_type = "Illumina 1.3+";
  }
  elsif (($min_qs_value >= 33) && ($max_qs_value <= 126)) {
    $qs_type = "Sanger / Illumina 1.8+";
  }
}


########################################
##  Print out the summary
if ($config -> get ("summary")) {
  printf "%u", $num_reads;
  printf "\t%u", $min_read_length;
  printf "\t%u", $max_read_length;
  printf "\t%u", $avg_read_length;
  printf "\t%.2f", $stddev;  
  
  printf "\t%u", $id1_size;
  printf "\t%u", $seq_size;
  printf "\t%u", $id2_size;
  printf "\t%u", $qs_size;
  printf "\t%u", $total_size;
  if (defined ($config -> get ("dqscores"))) {
    printf "\t%s", $qs_type;
  }
  printf "\n";
}
else {
  my $mib = 1024 * 1024;

  printf "II\tNumber of reads:\t%u\n", $num_reads;
  printf "II\tMinimum read length:\t%u\n", $min_read_length;
  printf "II\tMaximum read length:\t%u\n", $max_read_length;
  printf "II\tAverage read length:\t%u\n", $avg_read_length;
  printf "II\tStandard deviation:\t%.2f\n", $stddev;
  printf "II\t\n";
  printf "II\tID1:\t%u bytes\t%10.1f MiB\t%5.1f %%\n", $id1_size, $id1_size / $mib, $id1_size / $total_size * 100;
  printf "II\tSeq:\t%u bytes\t%10.1f MiB\t%5.1f %%\n", $seq_size, $seq_size / $mib, $seq_size / $total_size * 100;
  printf "II\tID2:\t%u bytes\t%10.1f MiB\t%5.1f %%\n", $id2_size, $id2_size / $mib, $id2_size / $total_size * 100;
  printf "II\tQS:\t%u bytes\t%10.1f MiB\t%5.1f %%\n", $qs_size, $qs_size / $mib, $qs_size / $total_size * 100;
  printf "II\t\n";
  printf "II\tID1 + Seq + ID2 + QS (All):\t%u bytes\t%10.1f MiB\t%5.1f %%\n", $total_size, $total_size / $mib, $total_size / $total_size * 100;
  printf "II\t\n";
  
  if (defined ($config -> get ("dqscores"))) {
    printf "II\tQuality score encoding (inferred):  %s\n", $qs_type;
  }
}

##  If requested, print out the distribution of read lengths
if (defined ($config -> get ("dlengths"))) {
  for (my $k = 0; $k < scalar (@seq_lengths); $k++) {
    printf $dlen_fp "%u\n", $seq_lengths[$k];
  }
  close ($dlen_fp);
}

##  If requested, print out the distribution of quality scores
if (defined ($config -> get ("dqscores"))) {
  for (my $k = 0; $k < $MAX_ASCII; $k++) {
    printf $dqs_fp "%u\t%u\n", $k, $qscores_acc[$k];
  }
  close ($dqs_fp);
}


=pod

=head1 NAME

fastq-summary.pl -- Collect statistics from FASTQ file.

=head1 SYNOPSIS

B<fastq-summary.pl> <input-file

=head1 DESCRIPTION

Collect statistics about the lengths (sizes) of each part of the FASTQ records.  Distribution of read lengths and quality scores can also be printed to separate files.  

Newline characters can be removed prior to all calculations if the --nonewline option is provided.

=head1 OPTIONS

=over 5

=item --dlengths I<filename>

The filename to write the distribution of read lengths to.  The number of rows in this file is equal to the number of records in the FASTQ file.

=item --dqscores I<filename>

The filename to write the distribution of quality scores to.  The number of rows in this file is equal to the number of quality scores in the FASTQ file (that is, it is approximately the "number of records * average read length").  

Since **each** quality score is checked, using this option increases the running time of this script significantly.  For example, for an "average" Illumina sequencing run without this option would take 5 minutes to process; with this option, the running time can increase to up to 5 hours.

=item --summary

Print the results on a single line, suitable for batch processing in order to create a tab-separated table.

=item --input I<filename>

Print the name of the input file.  Since input is taken from STDIN, the purpose of this argument is to work with --summary for batch processing.  This argument is optional.

=item --nonewline

Remove the newline character.  If the newline character is kept, then it would be the values reported in the Bioinformatics 2012 paper.

=item --verbose

Display verbose information about the execution of the program.

=item --help

Display this help message.

=back

=head1 EXAMPLE

=over 5

cat sample.fq | ./fastq-summary.pl 

=back

=head1 AUTHOR

Raymond Wan <rwan.work@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010-2019, Raymond Wan, All rights reserved.


