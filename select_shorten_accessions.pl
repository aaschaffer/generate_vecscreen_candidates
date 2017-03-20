#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to pull out accessions from full identifier and report only those accessions 
# that are not from EMBL or DDBJ and that have a version number
#
# Usage: select_shorten_accessions.pl --input <input file of identifiers>  
use strict;
use warnings;
use Getopt::Long;

require "epn-options.pm";

# variables related to command-line options
my $input_file_identifiers; #input accessions file 

# variables related to parsing the input file and shortening accessions
my $nextline;       #one line of the file
my $accession;      #one accession
my $gi;             #gi from defline
my $source;         #source from defline
my $big_identifier; #big identifier from defline

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
#       option          type       default               group   requires incompat   preamble-outfile   help-outfile
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,     undef,            "display this help",                  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--input",       "string", undef,                        1,    undef, undef,     "input identifiers file",  "File name <s> for identifiers",     \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'            => \$GetOptions_H{"-h"},
# required options
                'input=s'      => \$GetOptions_H{"--input"});

# This section needs to be kept in sync (manually) with the opt_Add() section above
my $synopsis = "select_shorten_accessions.pl: select identifiers not from DDBJ or EMBL and report on the accession part";
my $usage    = "Usage: select_shorten_accessions.pl\n";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define input file name
$input_file_identifiers = opt_Get("--input", \%opt_HH); 

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $input_file_identifiers) { $reqopts_errmsg .= "ERROR, --input option not used. It is required.\n"; }

if(($GetOptions_H{"-h"}) || ($reqopts_errmsg ne "") || (! $all_options_recognized)) { 
  opt_OutputHelp(*STDERR, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  elsif($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; } 
}
# Finished processing/checking command line options
####################################################

open(INPUT_IDENTIFIERS, "<", $input_file_identifiers) or die "Cannot open 1 $input_file_identifiers\n"; 

while(defined($nextline = <INPUT_IDENTIFIERS>)) {
    chomp($nextline);
    $big_identifier = $nextline;
    if($big_identifier !~ /^[>a-z]+\|(\d+)\|([a-z]+)\|(\S+)\|/) { 
      die "ERROR unable to parse identifier $big_identifier";
    }
    ($gi,$source,$accession) = ($1, $2, $3);
    if ((!($source eq "emb")) && (!($source eq "dbj"))) {
	if ($accession =~m/\.\d+/) {
	    print "$accession\n";
	}
    }
}
close(INPUT_IDENTIFIERS);
