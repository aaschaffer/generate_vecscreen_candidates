#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to eliminate one subset of accessions from another, ignoring the versions
# Usage: eliminate_analyzed_acc.pl --input <input accessions file>  --accessions <input file of accessions to exclude> --outfile <output accessions file>

use strict;
use warnings;
use Getopt::Long;

require "epn-options.pm";

# variables related to command line variables
my $input_file_superset;   #input superset file of accessions
my $input_file_accessions; #input file of accessions to exclude
my $output_file;           #output  file 

# variables related to parsing input and creating output
my $nextline;             #one line of the file
my $accession;            #one accession
my $accession_no_version; #one accessions without the version 
my %forbidden_accessions; #accessions to be excluded from the output list

# Command line and option processing using epn-options.pm
#
# opt_HH: 2D hash:
#         1D key: option name (e.g. "-h")
#         2D key: string denoting type of information 
#                 (one of "type", "default", "group", "requires", "incompatible", "preamble", "help")
#         value:  string explaining 2D key:
#                 "type":         "boolean", "string", "integer" or "real"
#                 "default":      default value for option
#                 "group":        integer denoting group number this option belongs to
#                 "requires":     string of 0 or more other options this option requires to work, each separated by a ','
#                 "incompatible": string of 0 or more other options this option is incompatible with, each separated by a ','
#                 "preamble":     string describing option for preamble section (beginning of output from script)
#                 "help":         string describing option for help section (printed if -h used)
#                 "setby":        '1' if option set by user, else 'undef'
#                 "value":        value for option, can be undef if default is undef
#
# opt_order_A: array of options in the order they should be processed
# 
# opt_group_desc_H: key: group number (integer), value: description of group for help output
my %opt_HH = ();
my @opt_order_A = ();
my %opt_group_desc_H = ();

# Add all options to %opt_HH and @opt_order_A.
# This section needs to be kept in sync (manually) with the &GetOptions call below
# The opt_Add() function is the way we add options to %opt_HH.
# It takes values of for each of the 2nd dim keys listed above.
#       option           type       default    group   requires incompat   preamble-outfile               help-outfile
opt_Add("-h",              "boolean", 0,           0,    undef, undef,     undef,                         "display this help",                  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--input",         "string", undef,        1,    undef, undef,     "input accessions file",       "File name <s> with accessions to consider",    \%opt_HH, \@opt_order_A);
opt_Add("--accessions",    "string", undef,        1,    undef, undef,     "input accessions to exclude", "File name <s> with accessions to exclude",     \%opt_HH, \@opt_order_A);
opt_Add("--outfile",       "string", undef,        1,    undef, undef,     "output file",                 "File name <s> of output accessions",           \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'               => \$GetOptions_H{"-h"},
# required options
                'input=s'      => \$GetOptions_H{"--input"},
                'accessions=s' => \$GetOptions_H{"--accessions"},
                'outfile=s'    => \$GetOptions_H{"--outfile"});

# This section needs to be kept in sync (manually) with the opt_Add() section above
my $synopsis = "eliminate_analyzed_acc.pl: eliminate a subset of vecscreen matches for a specified set of accessions\n";
my $usage    = "Usage: eliminate_analyzed_acc.pl\n";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define file names and retrieve options
$input_file_superset   = opt_Get("--input", \%opt_HH);
$input_file_accessions = opt_Get("--accessions", \%opt_HH);
$output_file           = opt_Get("--outfile", \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $input_file_superset)   { $reqopts_errmsg .= "ERROR, --input option not used. It is required.\n"; }
if(! defined $input_file_accessions) { $reqopts_errmsg .= "ERROR, --accessions option not used. It is required.\n"; }
if(! defined $output_file)           { $reqopts_errmsg .= "ERROR, --outfile option not used. It is required.\n"; }

if(($GetOptions_H{"-h"}) || ($reqopts_errmsg ne "") || (! $all_options_recognized)) { 
  opt_OutputHelp(*STDERR, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  elsif($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; } 
}
# Finished processing/checking command line options
####################################################

##########################################
# Read input files and create output files
##########################################

open(INPUT_SUPERSET,   "<", $input_file_superset)   or die "Cannot open 1 $input_file_superset\n"; 
open(INPUT_ACCESSIONS, "<", $input_file_accessions) or die "Cannot open 2 $input_file_accessions\n"; 
open(OUTPUT,           ">", $output_file)           or die "Cannot open 3 $output_file\n"; 

while(defined($nextline = <INPUT_ACCESSIONS>)) {
    chomp($nextline);
    ($accession_no_version) = ($nextline =~m/(\S+)\.\d+/);
    $forbidden_accessions{$accession_no_version} = 1;
}
close(INPUT_ACCESSIONS);

while(defined($nextline = <INPUT_SUPERSET>)) {
    chomp($nextline);
    $accession = $nextline;
    ($accession_no_version) = ($accession =~m/(\S+)\.\d+/);
    if (!defined($forbidden_accessions{$accession_no_version})) {
	print OUTPUT "$nextline\n";
    }
}
close (OUTPUT);
close(INPUT_SUPERSET);
