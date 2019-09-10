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
my $sample_fn_arg = "";

##  Data structures to keep track of the reference
my @reference_lines;
my %reference_markers_to_lines;

##  Accumulators
my $reference_total_markers = 0;
my $sample_total_markers = 0;
my $overlapping_markers = 0;


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

if (!defined ($config -> get ("sample"))) {
  printf STDERR "EE\tThe sample filename is required with the --sample option.\n";
  exit (1);
}
$sample_fn_arg = $config -> get ("sample");


########################################
##  Open the reference for reading
########################################

my $pos = 0;
open (my $reference_fp, "<", $reference_fn_arg) or die "EE\tCould not open $reference_fn_arg for reading";
while (<$reference_fp>) {
  my $line = $_;
  chomp $line;
  
  my $key = "";
  if ($line =~ /^M (.+) /) {
    $key = $1;
  }
  else {
    printf "%s\n", $line;
  }
  
  $reference_lines[$pos] = $line;  
  $reference_markers_to_lines{$key} = $pos;
  $pos++;
}
close ($reference_fp);
$reference_total_markers = $pos;


########################################
##  Main program body
########################################

open (my $sample_fp, "<", $sample_fn_arg) or die "EE\tCould not open $sample_fn_arg for reading";
while (<$sample_fp>) {
  my $line = $_;

  my @tmp = split /\t/, $line;
  my $sample_key = $tmp[1];
  
  if (defined ($reference_markers_to_lines{$sample_key})) {
    my $new_pos = $reference_markers_to_lines{$sample_key};
    printf "%s\n", $reference_lines[$new_pos];
    
    ##  Delete the hash
    delete ($reference_markers_to_lines{$sample_key});
    $overlapping_markers++;
  }
  $sample_total_markers++;
}

##  Even though we do not need them, we print out 
##    the remaining markers in the reference that 
##    did not exist in the sample
foreach my $sample_key (sort (keys %reference_markers_to_lines)) {
  my $new_pos = $reference_markers_to_lines{$sample_key};
  printf "%s\n", $reference_lines[$new_pos];
}


########################################
##  Print out overall statistics
########################################

if ($config -> get ("verbose")) {
  printf STDERR "II\tNumber of reference markers:  %u\n", $reference_total_markers;
  printf STDERR "II\tNumber of sample markers:  %u\n", $sample_total_markers;
  printf STDERR "II\tNumber of overlapping markers:  %u\n", $overlapping_markers;
}


=pod

=head1 NAME

beagle-reorder.pl -- Reorder a reference panel according to the order of the markers in a sample.

=head1 SYNOPSIS

B<beagle-reorder.pl> --reference I<reference panel> --sample I<sample> >new-reference-panel

=head1 DESCRIPTION

Reorder a reference panel in Beagle v3.x format according to the order of the markers in a sample.  Note that the markers are compared according to a B<case sensitive> match.

=head1 OPTIONS

=over 5

=item --reference I<filename>

The filename of the reference panel.  Only lines that start with "M" are considered and the marker is assumed to be in the second column of this space-separated file.

=item --sample I<filename>

The filename of the sample, which can be in either .bim or .map format.  The markers are assumed to be in the second column of this tab-separated file.

=item --verbose

Display verbose information about the execution of the program.

=item --help

Display this help message.

=back

=head1 EXAMPLE

=over 5

./beagle-reorder.pl --reference reference.bgl --sample sample.bim >new-reference.bgl

=back

=head1 AUTHOR

Raymond Wan <rwan.work@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2019, Raymond Wan, All rights reserved.


