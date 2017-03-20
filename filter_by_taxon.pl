#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to filter accessions by taxon
# Usage: filter_by_taxon.pl --input <input file from src_chk> --exclude <excluded list of taxa> --outfile <reduced list of accessions> 

use strict;
use warnings;
use Getopt::Long;

require "epn-options.pm";

# variables related to command line options
my $infile;   #input with accessions
my $taxafile; #input file with taxa to exclude
my $outfile;  #outfile script file

# variables related to reading input file and creating output
my $nextline;       #one line of input
my $line_count = 0; #count of filtering lines
my %excluded_taxa;  #hash of excluded taxa; define each entry to be 1 
my @fields;         #fields of one line

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
#       option           type       default    group   requires incompat   preamble-outfile    help-outfile
opt_Add("-h",              "boolean", 0,           0,    undef, undef,     undef,              "display this help",                  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--input",         "string", undef,        1,    undef, undef,     "input accessions", "File name <s> output by src_chk to subject to additional filtering",     \%opt_HH, \@opt_order_A);
opt_Add("--exclude",       "string", undef,        1,    undef, undef,     "excluded taxa",    "File name <s> with taxa to exclude, one per line",     \%opt_HH, \@opt_order_A);
opt_Add("--outfile",       "string", undef,        1,    undef, undef,     "output file",      "Name <s> of output file",                              \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'               => \$GetOptions_H{"-h"},
# required options
                'input=s'   => \$GetOptions_H{"--input"},
                'exclude=s' => \$GetOptions_H{"--exclude"},
                'outfile=s' => \$GetOptions_H{"--outfile"});

# This section needs to be kept in sync (manually) with the opt_Add() section above
my $synopsis = "filter_by_taxon.pl: filter input accessions by taxon";
my $usage    = "Usage: filter_by_taxon.pl\n";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define file names and retrieve options
$infile   = opt_Get("--input", \%opt_HH);
$taxafile = opt_Get("--exclude", \%opt_HH);
$outfile  = opt_Get("--outfile", \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $infile)   { $reqopts_errmsg .= "ERROR, --input option not used. It is required.\n"; }
if(! defined $taxafile) { $reqopts_errmsg .= "ERROR, --exclude option not used. It is required.\n"; }
if(! defined $outfile)  { $reqopts_errmsg .= "ERROR, --outfile option not used. It is required.\n"; }

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

open(INPUT,  "<", $infile)   or die "Cannot open $infile\n";
open(TAXA,   "<", $taxafile) or die "Cannot open $taxafile\n";
open(OUTPUT, ">", $outfile)  or die "Cannot open $outfile\n";

# parse excluded taxa 
while(defined($nextline = <TAXA>)) {
    chomp($nextline);
    $excluded_taxa{$nextline} = 1;
}
close(TAXA);

# for each input line, output it if it isn't an excluded taxa

# example first two lines of input file:
#accession	taxid	
#XM_020238554.1	4615	

$nextline = <INPUT>; #skip header line
while(defined($nextline = <INPUT>)) {
    chomp($nextline);
    @fields = split /\t/, $nextline;
    if (!(defined($excluded_taxa{$fields[1]}))) {
	print OUTPUT "$fields[0]\n";
    }
}
close(INPUT);
close(OUTPUT);
