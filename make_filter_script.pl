#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to make a script to filter accessions
# Usage: make_filter_script.pl --instructions <text_file> --outfile <script file> 

use strict;
use warnings;
use Getopt::Long;

require "epn-options.pm";

# variables related to command line options
my $infile; #input instructions

# variables related to parsing input file and creating output file
my $scriptfile;     #outfile script file
my $nextline;       #one line of input
my $line_count = 0; #count of filtering lines

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
#       option           type       default    group   requires incompat   preamble-outfile   help-outfile
opt_Add("-h",              "boolean", 0,           0,    undef, undef,     undef,            "display this help",                  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--instructions",  "string", undef,        1,    undef, undef,     "instructions",   "File name <s> with Entrez queries to use in filtering",  \%opt_HH, \@opt_order_A);
opt_Add("--outfile",       "string", undef,        1,    undef, undef,     "output file",    "Name <s> of output script file",    \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'               => \$GetOptions_H{"-h"},
# required options
                'instructions=s'  => \$GetOptions_H{"--instructions"},
                'outfile=s'       => \$GetOptions_H{"--outfile"});

# This section needs to be kept in sync (manually) with the opt_Add() section above
my $synopsis = "make_filter_script.pl: prepare a shell script for filtering accessions";
my $usage    = "Usage: make_filter_script.pl\n";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define file names and retrieve options
$infile      = opt_Get("--instructions", \%opt_HH); 
$scriptfile  = opt_Get("--outfile",      \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $infile)     { $reqopts_errmsg .= "ERROR, --instructions option not used. It is required.\n"; }
if(! defined $scriptfile) { $reqopts_errmsg .= "ERROR, --outfile option not used. It is required.\n"; }

if(($GetOptions_H{"-h"}) || ($reqopts_errmsg ne "") || (! $all_options_recognized)) { 
  opt_OutputHelp(*STDERR, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  elsif($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; } 
}
# Finished processing/checking command line options
####################################################

###############################################
# Read the instructions and create the script 
###############################################
open(INSTR, "<", $infile) or die "Cannot open $infile\n";
open(SCRIPT, ">", $scriptfile) or die "Cannot open $scriptfile\n";
print SCRIPT "\tcurrent=`cat \$1 \| epost -db nuccore -format acc`";
print SCRIPT "\n";
print SCRIPT "\tfor filt in \\";
print SCRIPT "\n";
while(defined($nextline = <INSTR>)) {
    chomp($nextline);
    if ($line_count > 0) {
	print SCRIPT " \\\n";
    }
    print SCRIPT "\t\t\'$nextline\' ";
    $line_count++;
}
print SCRIPT "\n";
print SCRIPT "\t do\n";
print SCRIPT "\t\tcurrent=`echo \"\$current\" \| efilter -query \"\$filt\"` \n";
print SCRIPT "\# \t\techo \"\$current\" \| xtract -pattern ENTREZ_DIRECT -element Count\n";
print SCRIPT "\t done\n";
print SCRIPT "\t echo \"\$current\" \| efetch -format acc\n";

close(INSTR);
close(SCRIPT);
