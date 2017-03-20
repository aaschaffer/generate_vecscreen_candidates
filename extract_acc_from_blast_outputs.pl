#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to extract accessions from blast outputs.
# 
# Usage: extract_acc_from_blast_outputs.pl --input <list of output files> 

use strict;
use warnings;
use Getopt::Long;
use Cwd;

require "epn-options.pm";
require "vecscreen_candidate_generation.pm";

# variables related to command line options
my $input_file;      #input file with list of output files
my $be_verbose;      #'1' if --verbose, echo commands as they're run
my $keep_temp_files; #'1' if --keep, keep temporary files

# variables related to parsing the input file
my $count;      #count of files
my @full_names; #array of file names

# variables for (temporary) output file names
my $script_name1         = "cut_acc_script.sh";     #output script to cut the accession column
my $script_name2         = "sort_acc_script.sh";    #output script to sort and uniq the accessions
my $script_name3         = "cat_acc_script.sh";     #output script to print the accessions
my $temp_all_accessions  = "temp_all_matches.txt";  #temporary file of all accession
my $temp_uniq_accessions = "temp_uniq_matches.txt"; #temporary file of uniq accessions
my @temp_files_A = ();  # array of temporary files

my $s; #loop index

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
#       option          type       default               group   requires incompat   preamble-outfile       help-outfile
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,     undef,                 "display this help",                  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--input",      "string",  undef,                    1,    undef, undef,     "input list of files", "Input list <s> of output files",     \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "non-required options";
opt_Add("--verbose",    "boolean", 0,                        2,    undef, undef,     "verbose mode",                 "verbose mode: output commands as they are executed",   \%opt_HH, \@opt_order_A);
opt_Add("--keep",       "boolean", 0,                        2,    undef, undef,     "keep all intermediate files", "keep all intermediate files", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'            => \$GetOptions_H{"-h"},
# required options
                'input=s'      => \$GetOptions_H{"--input"},
                'verbose'      => \$GetOptions_H{"--verbose"},
                'keep'         => \$GetOptions_H{"--keep"});

# This section needs to be kept in sync (manually) with the opt_Add() section above
my $synopsis = "extract_acc_from_blast_outputs.pl extract accessions from blast outputs\n";
my $usage    = "Usage: extract_acc_from_blast_outputs.pl\n";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define file names and retrieve options
$input_file      = opt_Get("--input", \%opt_HH); 
$be_verbose      = opt_Get("--verbose",                  \%opt_HH);
$keep_temp_files = opt_Get("--keep",                     \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $input_file) { $reqopts_errmsg .= "ERROR, --input option not used. It is required.\n"; }

if(($GetOptions_H{"-h"}) || ($reqopts_errmsg ne "") || (! $all_options_recognized)) { 
  opt_OutputHelp(*STDERR, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  elsif($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; } 
}
# Finished processing/checking command line options
####################################################

######################################################
# Step 1. Read input file
######################################################
$count = parse_filelist_file($input_file, \@full_names);

######################################################
# Step 2. Extract the accessions from each file
######################################################
open(CUT_SCRIPT, ">", $script_name1) or die "Cannot open 2 $script_name1\n";
print CUT_SCRIPT "cut -f2 $full_names[0] > $temp_all_accessions \n"; 
for ($s = 0; $s < $count; $s++){ 
    print CUT_SCRIPT "cut -f2 $full_names[$s] >> $temp_all_accessions \n";
}
close(CUT_SCRIPT);
push(@temp_files_A, $script_name1);
push(@temp_files_A, $temp_all_accessions);
run_command("chmod +x $script_name1", $be_verbose);
run_command($script_name1, $be_verbose);

open(SORT_SCRIPT, ">$script_name2") or die "Cannot open 3 $script_name2\n";
print SORT_SCRIPT "sort $temp_all_accessions | uniq > $temp_uniq_accessions\n";
close(SORT_SCRIPT); 
push(@temp_files_A, $script_name2);
push(@temp_files_A, $temp_uniq_accessions);
run_command("chmod +x $script_name2", $be_verbose);
run_command($script_name2, $be_verbose);

open(CAT_SCRIPT, ">$script_name3") or die "Cannot open 4 $script_name3\n";
print CAT_SCRIPT "cat $temp_uniq_accessions\n";
close(CAT_SCRIPT); 
push(@temp_files_A, $script_name3);
run_command("chmod +x $script_name3", $be_verbose);
run_command($script_name3, $be_verbose);

# remove temporary files unless --keep
sleep(0.1); # pause 1/10th of a second, this can prevent issues with removing files that have just been closed with close()
if(! $keep_temp_files) { 
  foreach my $temp_file (@temp_files_A) { 
    unlink $temp_file;
  }
}
    

