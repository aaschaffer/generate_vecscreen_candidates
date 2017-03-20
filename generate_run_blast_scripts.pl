#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Author: Alejandro Schaffer
# Code to generate blast runs for each of a list of related sequence files for vecscreen testing
# 
# Usage: generate_blast_script.pl --input <list of fasta files> --db <database> --outprefix <prefix of outfile name>

use strict;
use warnings;
use Getopt::Long;
use Cwd;

require "epn-options.pm";
require "vecscreen_candidate_generation.pm";

# variables related to command line options
my $input_file;     #input file with list of fasta files
my $db_name;        #name of database to use in queries
my $output_prefix;  #prefix of output file name
my $be_verbose;     #'1' if --verbose used, else '0'

# variables related to step 1, parsing the input file
my @full_names;         #full names of input fasta files
my $count;              #count of files
my $existing_files_str; #list of existing files we are about to create

# variables related to step 2, preparation of the BLAST db
my $blastdbcmd_cmd;  #command for running blastdbcmd
my $directory;       # current working directory

# variables related to step 3, creation of the qsub script and individual job scripts
my $output_script_name;         #output script for a single fasta file
my $qsub_script_name;           #name of file containing commands to submit to the farm
my $s;                          #loop index
my $qsub_common_str;            #string to print to all qsub scripts
my $blast_error_file_name;      #file to hold errors from the farm script 
my $blast_diagnostic_file_name; #file to hold diagnostic outputs from the farm script 
my $blast_output_file_name;     #file to hold blast outputs from the farm script 
my $query_name;                 #full name of one query file

#########################################################
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
#       option          type       default group   requires incompat   preamble-outfile       help-outfile
opt_Add("-h",           "boolean", 0,          0,    undef, undef,     undef,                 "display this help",                    \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"1"} = "required options";
opt_Add("--input",      "string",  undef,      1,    undef, undef,     "input list of files", "REQUIRED: Input list <s> of fasta files",        \%opt_HH, \@opt_order_A);
opt_Add("--outprefix",  "string",  undef,      1,    undef, undef,     "output file prefix",  "REQUIRED: Prefix <s> of names of output files",  \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "non-required options";
opt_Add("--db",         "string",  "nr",       2,    undef, undef,     "database for blastn", "database <s> for blastn (default nr)",                 \%opt_HH, \@opt_order_A);
opt_Add("--verbose",    "boolean", 0,          2,    undef, undef,     "verbose mode",        "verbose mode: output commands as they are executed",   \%opt_HH, \@opt_order_A);
opt_Add("--wait",       "boolean", 0,          2,    undef, undef,     "do not submit jobs",  "do not submit jobs, just create qsub script and exit", \%opt_HH, \@opt_order_A);


# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'           => \$GetOptions_H{"-h"},
                'input=s'     => \$GetOptions_H{"--input"},
                'db_name=s'   => \$GetOptions_H{"--db"},
                'outprefix=s' => \$GetOptions_H{"--outprefix"},
                'verbose'     => \$GetOptions_H{"--verbose"},
                'wait'        => \$GetOptions_H{"--wait"});

my $synopsis = "generate_blast_script.pl: generate blast scripts for a list of fasta files\n\n";
my $usage    = "Usage: generate_blast_script.pl ";

my $executable    = $0;
my $date          = scalar localtime();
my $version       = "0.01";
my $releasedate   = "Jan 2017";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# store option values
$input_file    = opt_Get("--input",     \%opt_HH);
$db_name       = opt_Get("--db",        \%opt_HH);
$output_prefix = opt_Get("--outprefix", \%opt_HH);
$be_verbose    = opt_Get("--verbose",   \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $input_file)    { $reqopts_errmsg .= "ERROR, --input option not used. It is required.\n"; }
if(! defined $output_prefix) { $reqopts_errmsg .= "ERROR, --outprefix option not used. It is required.\n"; }
if(! defined $db_name)       { $reqopts_errmsg .= "ERROR, --db option not used. It is required.\n"; }

if(($GetOptions_H{"-h"}) || ($reqopts_errmsg ne "") || (! $all_options_recognized)) { 
  opt_OutputHelp(*STDERR, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  elsif($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; } 
}
# Finished processing/checking command line options
####################################################

##############################################################
# Step 1: Parse input file and check that files exist as we go
##############################################################
# each file may be either a relative path or absolute path
# we first check if it's a relative path and use that if the 
# file exists, if not, we try the absolute path and use that
$count = parse_filelist_file($input_file, \@full_names);

# determine if any of the files we are about to create already exist, and if so die
# telling the user to remove them first
$existing_files_str = "";
$directory = cwd() . "/";
$qsub_script_name = $output_prefix . "qsub" . "script";
if(-e $qsub_script_name) { 
  $existing_files_str .= "\t" . $qsub_script_name . "\n";
}
for ($s = 0; $s < $count; $s++){ 
  $output_script_name = "$output_prefix" . "$s" . "\.csh";
  $blast_output_file_name = $directory . $output_prefix . ".results" . "$s" . "\.out"; 
  if(-e $output_script_name) { 
    my $file_to_print = $output_script_name;
    $file_to_print =~ s/^.+\///; # remove leading path
    $existing_files_str .= "\t" . $file_to_print . "\n";
  }
  if(-e $blast_output_file_name) { 
    my $file_to_print = $blast_output_file_name;
    $file_to_print =~ s/^.+\///; # remove leading path
    $existing_files_str .= "\t" . $file_to_print . "\n";
  }
}
if($existing_files_str ne "") { 
  die "ERROR, some files exist which this script will overwrite.\n\nEither rename, move or delete them and then rerun.\n\nYou may want to move/remove all files that begin with \"$output_prefix\"\nto avoid confusion with the eventual output of this run.\n\nOr alternatively, use a different output prefix than \"$output_prefix\".\n\nList of files that will be overwritten:\n$existing_files_str";
}

################################
# STEP 2: Prepare BLAST database
################################
run_command("blastdbcmd -info -db $db_name -dbtype nucl >&  /dev/null", $be_verbose);

#############################################################
# STEP 3: Create qsub script and individual job shell scripts
#############################################################
# create the common strings that get printed to all qsub commands
$qsub_common_str = "\#!/bin/tcsh\n";
$qsub_common_str .= "\#\$ -P unified\n";
$qsub_common_str .= "\n";
$qsub_common_str .= "\# list resource request options\n";
$qsub_common_str .= "\#\$ -l h_vmem=32G,reserve_mem=32G,mem_free=32G\n";
$qsub_common_str .= "\n";
$qsub_common_str .= "\# split stdout and stderr files (default is they are joined into one file)\n";
$qsub_common_str .= "\#\$ -j n\n";
$qsub_common_str .= "\n";
$qsub_common_str .= "\# job is re-runnable if SGE fails while it's running (e.g. the host reboots)\n";
$qsub_common_str .= "\#\$ -r y\n";
$qsub_common_str .= "\# stop email from being sent at the end of the job\n";
$qsub_common_str .= "\#\$ -m n\n";
$qsub_common_str .= "\n";
$qsub_common_str .= "\# trigger NCBI facilities so runtime enviroment is similar to login environment\n";
$qsub_common_str .= "\#\$ -v SGE_FACILITIES\n";
$qsub_common_str .= "\n";

open(QSUB, ">", $qsub_script_name) or die "Cannot open 2 $qsub_script_name\n"; 

# create a different script for each job
for ($s = 0; $s < $count; $s++){ 
    $output_script_name = "$output_prefix" . "$s" . "\.csh";
    # output to qsub script
    print QSUB "chmod +x $output_script_name\n";
    print QSUB "qsub $output_script_name\n";

    # output to shell script qsub will submit
    open(SCRIPT, ">", $output_script_name) or die "Cannot open 2 $output_script_name\n"; 
    # print qsub options that are in common to all jobs
    print SCRIPT $qsub_common_str;

    # output definition stderr and stdout files
    $blast_error_file_name = "blastrun_" . "$s" . "\.err";
    $blast_diagnostic_file_name = "blastrun_" . "$s" . "\.out";
    print SCRIPT "\#define stderr file\n"; 
    print SCRIPT "\#\$ -e $blast_error_file_name\n";
    print SCRIPT "\# define stdout file\n";
    print SCRIPT "\#\$ -o $blast_diagnostic_file_name\n";

    # output command
    $query_name = "$full_names[$s]";
    $blast_output_file_name = $directory . $output_prefix . ".results" . "$s" . "\.out"; 
    print SCRIPT "echo \"starting blastn\"\n\n";
    print SCRIPT "/usr/bin/blastn -word_size 20 -ungapped -query $query_name -db $db_name -show_gis -perc_identity 96 -xdrop_ungap 4 -dust no -outfmt \" 6 qaccver sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore\" -out $blast_output_file_name";
    print SCRIPT "\n";
    close(SCRIPT);
    
    # make the script executable
    run_command("chmod +x $output_script_name", $be_verbose);
}
close(QSUB);
run_command("chmod +x $qsub_script_name", $be_verbose);
if(opt_Get("--wait", \%opt_HH)) { 
  print STDERR "Script with qsub call saved as $qsub_script_name, not executed due to --wait.\nYou can execute it later with the command:\n$qsub_script_name\n";
}
else {
  run_command("$qsub_script_name", $be_verbose);
}

