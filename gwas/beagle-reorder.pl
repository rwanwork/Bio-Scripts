#!/usr/bin/env perl
#  Author:  Raymond Wan
#  Copyright (C) 2019, Raymond Wan, All rights reserved.

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



########################################
##  Important variables
########################################

##  Input arguments
my $reference_fn_arg = "";
my $markers_fn_arg = "";
my $new_reference_fn_arg = "";
my $new_markers_fn_arg = "";
my $sample_fn_arg = "";

##  Data structures to keep track of the reference
my @reference_lines;
my %reference_to_lines;

##  Data structures to keep track of the markers
my @markers_lines;
my %markers_to_lines;

##  Accumulators
my $reference_total = 0;
my $markers_total = 0;
my $sample_total = 0;
my $overlapping = 0;


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

$config -> define ("reference", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s",
});                            ##  Filename of the reference panel in Beagle format
$config -> define ("markers", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s",
});                            ##  Filename of the markers
$config -> define ("newreference", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s",
});                            ##  Filename of the reference panel in Beagle format
$config -> define ("newmarkers", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s",
});                            ##  Filename of the markers
$config -> define ("sample", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s",
});                            ##  Filename of the sample
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

if (!defined ($config -> get ("reference"))) {
  printf STDERR "EE\tThe reference panel filename is required with the --reference option.\n";
  exit (1);
}
$reference_fn_arg = $config -> get ("reference");

if (!defined ($config -> get ("markers"))) {
  printf STDERR "EE\tThe markers filename is required with the --markers option.\n";
  exit (1);
}
$markers_fn_arg = $config -> get ("markers");


if (!defined ($config -> get ("newreference"))) {
  printf STDERR "EE\tThe output reference panel filename is required with the --newreference option.\n";
  exit (1);
}
$new_reference_fn_arg = $config -> get ("newreference");

if (!defined ($config -> get ("newmarkers"))) {
  printf STDERR "EE\tThe output markers filename is required with the --newmarkers option.\n";
  exit (1);
}
$new_markers_fn_arg = $config -> get ("newmarkers");


if (!defined ($config -> get ("sample"))) {
  printf STDERR "EE\tThe sample filename is required with the --sample option.\n";
  exit (1);
}
$sample_fn_arg = $config -> get ("sample");


########################################
##  Open files for writing
########################################

open (my $new_reference_fp, ">", $new_reference_fn_arg) or die "EE\tCould not open $new_reference_fn_arg for writing";
open (my $new_markers_fp, ">", $new_markers_fn_arg) or die "EE\tCould not open $new_markers_fn_arg for writing";


########################################
##  Open the reference for reading
########################################

my $reference_pos = 0;
open (my $reference_fp, "<", $reference_fn_arg) or die "EE\tCould not open $reference_fn_arg for reading";
while (<$reference_fp>) {
  my $line = $_;
  chomp $line;
  
  ##  Keys are lines that start with "M" and occupy
  ##    the second field
  my $key = "";
  if ($line =~ /^M (\S+) /) {
    $key = $1;
  }
  else {
    printf $new_reference_fp "%s\n", $line;
  }
  
  if (defined ($reference_to_lines{$key})) {
    printf STDERR "EE\tUnexpected duplicate key in reference panel:  [%s]\n", $key;
    exit (1);
  }
  
  $reference_lines[$reference_pos] = $line;  
  $reference_to_lines{$key} = $reference_pos;
  $reference_pos++;
}
close ($reference_fp);
$reference_total = $reference_pos;


########################################
##  Open the markers for reading
########################################

my $markers_pos = 0;
open (my $markers_fp, "<", $markers_fn_arg) or die "EE\tCould not open $markers_fn_arg for reading";
while (<$markers_fp>) {
  my $line = $_;
  chomp $line;
  
  ##  Keys are in the first column
  my $key = "";
  if ($line =~ /^(\S+)\s/) {
    $key = $1;
  }
  else {
    printf $new_markers_fp "%s\n", $line;
  }
  
  if (defined ($markers_to_lines{$key})) {
    printf STDERR "EE\tUnexpected duplicate key in markers:  %s\n", $key;
    exit (1);
  }
  
  $markers_lines[$markers_pos] = $line;  
  $markers_to_lines{$key} = $markers_pos;
  $markers_pos++;
}
close ($markers_fp);
$markers_total = $markers_pos;


########################################
##  Main program body
########################################

open (my $sample_fp, "<", $sample_fn_arg) or die "EE\tCould not open $sample_fn_arg for reading";
while (<$sample_fp>) {
  my $line = $_;

  my @tmp = split /\t/, $line;
  my $sample_key = $tmp[1];
  
  if (defined ($reference_to_lines{$sample_key})) {
    my $new_ref_pos = $reference_to_lines{$sample_key};
    my $new_markers_pos = $markers_to_lines{$sample_key};
    
    printf $new_reference_fp "%s\n", $reference_lines[$new_ref_pos];
    printf $new_markers_fp "%s\n", $markers_lines[$new_markers_pos];
    
    ##  Delete the hash
    delete ($reference_to_lines{$sample_key});
    
    ##  Delete the hash
    delete ($markers_to_lines{$sample_key});
    
    $overlapping++;
  }
  $sample_total++;
}

##  Even though we do not need them, we print out 
##    the remaining markers in the reference that 
##    did not exist in the sample
foreach my $sample_key (sort (keys %reference_to_lines)) {
  my $new_pos = $reference_to_lines{$sample_key};
  printf $new_reference_fp "%s\n", $reference_lines[$new_pos];
}

foreach my $sample_key (sort (keys %markers_to_lines)) {
  my $new_pos = $markers_to_lines{$sample_key};
  printf $new_markers_fp "%s\n", $markers_lines[$new_pos];
}


########################################
##  Open files for writing
########################################

close ($new_reference_fp);
close ($new_markers_fp);


########################################
##  Print out overall statistics
########################################

if ($config -> get ("verbose")) {
  printf STDERR "II\tSize of reference:  %u\n", $reference_total;
  printf STDERR "II\tSize of markers:  %u\n", $markers_total;
  printf STDERR "II\tSize of sample:  %u\n", $sample_total;
  printf STDERR "II\tNumber of overlapping markers:  %u\n", $overlapping;
}


=pod

=head1 NAME

beagle-reorder.pl -- Reorder a reference panel according to the order of the markers in a sample.

=head1 SYNOPSIS

B<beagle-reorder.pl> --reference I<reference panel> --markers I<markers> --new reference I<new reference panel> --newmarkers I<new markers> --sample I<sample> >new-reference-panel

=head1 DESCRIPTION

Reorder a reference panel in Beagle v3.x format according to the order of the markers in a sample.  Note that the markers are compared according to a B<case sensitive> match.

Three inputs are required:  the reference panel in Beagle format, the markers, and the sample to impute.  The re-ordered reference panel and the markers are output while the sample is unchanged.

=head1 OPTIONS

=over 5

=item --reference I<filename>

The filename of the reference panel.  Only lines that start with "M" are considered and the marker is assumed to be in the second column of this space-separated file.

=item --newreference I<filename>

The output filename of the reference panel.

=item --markers I<filename>

The filename of the markers list.  Every line is considered and the list of markers is in the first column.

=item --newmarkers I<filename>

The output filename of the markers.

=item --sample I<filename>

The filename of the sample, which can be in either .bim or .map format.  The markers are assumed to be in the second column of this tab-separated file.

=item --verbose

Display verbose information about the execution of the program.

=item --help

Display this help message.

=back

=head1 EXAMPLE

=over 5

./beagle-reorder.pl --reference data.bgl --markers data.markers --newreference data2.bgl --newmarkers data2.markers --sample sample.bim >new-reference.bgl

=back

=head1 AUTHOR

Raymond Wan <rwan.work@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2019, Raymond Wan, All rights reserved.


