#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Authors: Alejandro Schaffer and Eric Nawrocki
# 
# Code to reduce a set of matches between a BLASTable database and
# vectors to generate a set of sequences that may have vescreen
# matches of interest and meet the filtering criteria.
# 
# There can be many false negatives (i.e., sequences reported that do
# not have a vecscreen match.
# 
# There can be false positives in the sense that sequence that would
# have vecscreen matches get excluded because of the filtering
# criteria.
# 
# This program is meant to be run within NCBI as it assumes access to
# some NCBI command-line utilities.
# 
# Usage: filter_vecscreen_candidates.pl \ 
#        --input_match_files <input file with list of BLAST output files> (REQUIRED) \
#        --input_filters <Entrez queries to use as filters> (REQUIRED) \ 
#        --input_taxa_excluded <input file of taxids to exclude> (REQUIRED) \ 
#        --output <output FASTA file of candidates> (optional) \ 
#        --input_exclude_accessions <file with accessions to be excluded> (optional) \
#        --verbose (optional) \ 
#        --keep (optional)


use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(gettimeofday); # for timings

require "epn-options.pm";
require "vecscreen_candidate_generation.pm";

# variables related to command line options
my $input_matches_file;        #input file with list of BLAST output files
my $input_filters_file;        #input file with list of Entrez filters 
my $input_tax_exclusion_file;  #file with taxids to exclude, one per row
my $input_exclusion_acc_file; #input file of accessions to exclude
my $output_fasta_candidate_file; #output file of candidate sequences in FASTA format
my $be_verbose; #did user specify verbose mode, in which case extra columns are printed
my $keep_temp_files; #should we keep temporary files

# output files created by this script and removed unless --keep used
my $temp_initial_matches_file          = "initial_candidate_matches.txt";             #full accessions that have BLAST matches
my $temp_initial_accessions_file       = "initial_candidate_short_acc.txt";           #short accessions that have BLAST matches
my $temp_Entrez_filter_script          = "Entrez_filter_script.sh";                   #script to filter out accessions based on Entrez queries
my $temp_postEntrez_matches_file       = "postEntrez_candidate_accessions.txt";       #accessions that pass Entrez filtering criteria
my $temp_srcchk_output_file            = "taxonomy_info.txt";                         #taxonomy output file 
my $temp_post_taxonomy_matches_file    = "post_taxonomy_candidate_accessions.txt";    #accessions that pass taxonomy filtering criteria
my $temp_post_all_filters_matches_file = "post_all_filters_candidate_accessions.txt"; #accessions that pass filtering by previously studied accessions

# executable commands
my $srcchk                                = "srcchk";
my $extract_accessions_from_blast_outputs = "extract_acc_from_blast_outputs.pl";
my $select_shorten_accessions             = "select_shorten_accessions.pl";
my $eliminate_analyzed_acc                = "eliminate_analyzed_acc.pl";
my $make_filter_script                    = "make_filter_script.pl";
my $filter_by_taxon                       = "filter_by_taxon.pl"; 
my $get_fasta                             = "get_fasta_from_acc.sh";

# make sure all required scripts exist in current directory (may need to relax this eventually)
foreach my $script ($extract_accessions_from_blast_outputs, $select_shorten_accessions, $eliminate_analyzed_acc, $make_filter_script, $filter_by_taxon, $get_fasta) { 
  if(! -x "./" . $script) { 
    die "ERROR required executable $script not in current directory";
  }
}

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
$opt_group_desc_H{"1"} = "required options specifying input/output files";
#        option                       type       default group   requires incompat preamble-output                                        help-output
opt_Add("--input_match_files",        "string",  undef,      1,    undef, undef,   "input file with list of BLAST output files",          "File name <s> with list of files that contain BLAST matches between vectors and a database", \%opt_HH, \@opt_order_A);
opt_Add("--input_filters_file",       "string",  undef,      1,    undef, undef,   "input file with Entrez queries to use as filters",    "File name <s> with Entrez queries to use as filters",                                        \%opt_HH, \@opt_order_A);
opt_Add("--input_tax_exclusion_file", "string",  undef,      1,    undef, undef,   "input file with taxids to exclude",                   "File name <s> with taxids to exclude",                                                       \%opt_HH, \@opt_order_A);
opt_Add("--output",                   "string",  undef,      1,    undef, undef,   "output file for candidate sequences in FASTA format", "Output file name <s> with candidate sequences in FASTA format",                              \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "other options (not required)";
opt_Add("--input_exclude_accessions", "string",  undef,      2,    undef, undef,   "list of accessions to exclude",                       "input name <s> of accessions to exclude",             \%opt_HH, \@opt_order_A);
opt_Add("--verbose",                  "boolean", 0,          2,    undef, undef,   "be verbose",                                          "be verbose in output",                                \%opt_HH, \@opt_order_A);
opt_Add("--keep",                     "boolean", 0,          2,    undef, undef,   "keep all intermediate files (e.g. vecscreen output)", "keep all intermediate files (e.g. vecscreen output)", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $all_options_recognized =
    &GetOptions('h'            => \$GetOptions_H{"-h"},
                'input_match_files=s'        => \$GetOptions_H{"--input_match_files"},
                'input_filters_file=s'       => \$GetOptions_H{"--input_filters_file"},
                'input_tax_exclusion_file=s' => \$GetOptions_H{"--input_tax_exclusion_file"},
                'output=s'                   => \$GetOptions_H{"--output"},
                'input_exclude_accessions=s' => \$GetOptions_H{"--input_exclude_accessions"},
                'verbose'                    => \$GetOptions_H{"--verbose"},
                'keep'                       => \$GetOptions_H{"--keep"});


#my $synopsis    = "filter_vecscreen_candidates.pl: given accessions as BLAST matches that are candidates to have vecscreen matches,\nfilter them by Entrez queries, taxonomy, and previous matches;\noutput is a FASTA file of surviving candidates\n";
my $synopsis    = "filter_vecscreen_candidates.pl: filter candidate accessions with vecscreen matches by Entrez queries, taxonomy and previous matches";
my $usage       = "Usage: filter_vecscreen_candidates.pl ";
my $total_seconds = -1 * seconds_since_epoch(); # by multiplying by -1, we can just add another seconds_since_epoch call at end to get total time
my $executable    = $0;
my $date          = scalar localtime();
my $version       = "0.01";
my $releasedate   = "Aug 2017";

# set options in %opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define file names and retrieve options
$input_matches_file          = opt_Get("--input_match_files",        \%opt_HH); 
$input_filters_file          = opt_Get("--input_filters_file",       \%opt_HH);
$input_tax_exclusion_file    = opt_Get("--input_filters_file",       \%opt_HH);
$output_fasta_candidate_file = opt_Get("--output",                   \%opt_HH);
$input_exclusion_acc_file    = opt_Get("--input_exclude_accessions", \%opt_HH);
$be_verbose                  = opt_Get("--verbose",                  \%opt_HH);
$keep_temp_files             = opt_Get("--keep",                     \%opt_HH);

# We die if any of: 
# - non-existent option is used
# - any of the required options are not used. 
# - -h is used
my $reqopts_errmsg = "";
if(! defined $input_matches_file)          { $reqopts_errmsg .= "ERROR, --input_match_files option not used. It is required.\n"; }
if(! defined $input_filters_file)          { $reqopts_errmsg .= "ERROR, --input_filters_file option not used. It is required.\n"; }
if(! defined $input_tax_exclusion_file)    { $reqopts_errmsg .= "ERROR, --input_tax_exclusion_file option not used. It is required.\n"; }
if(! defined $output_fasta_candidate_file) { $reqopts_errmsg .= "ERROR, --output option not used. It is required.\n"; }

if(($reqopts_errmsg ne "") || (! $all_options_recognized) || ($GetOptions_H{"-h"})) {
  output_banner(*STDOUT, $version, $releasedate, $synopsis, $date);
  opt_OutputHelp(*STDOUT, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if($GetOptions_H{"-h"})          { exit 0; } # -h, exit with 0 status
  if   ($reqopts_errmsg ne "")     { die $reqopts_errmsg; }
  elsif(! $all_options_recognized) { die "ERROR, unrecognized option;"; }
  else                             { exit 0; } # -h, exit with 0 status
}

# output banner and preamble
my @arg_desc_A = (); # necessary to pass into opt_OutputPreamble()
my @arg_A      = (); # necessary to pass into opt_OutputPreamble()
output_banner(*STDOUT, $version, $releasedate, $synopsis, $date);
opt_OutputPreamble(*STDOUT, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# Finished processing/checking command line options
####################################################

######################################################
# Step 1. Call extract_accessions_from_blast_outputs #
######################################################
my $progress_w = 50; # the width of the left hand column in our progress output, hard-coded
my $start_secs = output_progress_prior("Running extract_accessions_from_blast_ouptuts ", $progress_w, undef, *STDOUT);
run_command("$extract_accessions_from_blast_outputs --input $input_matches_file > $temp_initial_matches_file", $be_verbose); 
my $desc_str = sprintf("output saved as $temp_initial_matches_file%s", opt_Get("--keep", \%opt_HH) ? "" : " (temporarily)");
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

######################################################
# Step 2. Select GenBank accessions and shorten them #
######################################################
$start_secs = output_progress_prior("Selecting and shortening GenBank accessions", $progress_w, undef, *STDOUT);
run_command("$select_shorten_accessions --input $temp_initial_matches_file > $temp_initial_accessions_file", $be_verbose);
$desc_str = sprintf("output saved as $temp_initial_accessions_file%s", opt_Get("--keep", \%opt_HH) ? "" : " (temporarily)");
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

##########################################################
# Step 3. Apply Entrez filters to initial accession list #
##########################################################
$start_secs = output_progress_prior("Applying Entrez filters", $progress_w, undef, *STDOUT);
run_command("$make_filter_script --instructions $input_filters_file  --outfile $temp_Entrez_filter_script", $be_verbose);
run_command("chmod +x $temp_Entrez_filter_script", 0); # 0: don't echo command to STDOUT
run_command("$temp_Entrez_filter_script $temp_initial_accessions_file > $temp_postEntrez_matches_file", $be_verbose);
$desc_str = sprintf("output saved as $temp_postEntrez_matches_file%s", opt_Get("--keep", \%opt_HH) ? "" : " (temporarily)");
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

##############################################################
# Step 4. Run srcchk to get taxonomy of remaining accessions #
##############################################################
$start_secs = output_progress_prior("Running srcchk to get taxonomy information", $progress_w, undef, *STDOUT);
run_command("$srcchk -i $temp_postEntrez_matches_file -f TaxID  -o $temp_srcchk_output_file", $be_verbose);
$desc_str = sprintf("output saved as $temp_srcchk_output_file%s", opt_Get("--keep", \%opt_HH) ? "" : " (temporarily)");
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

#########################################################
# Step 5. Apply taxonomy filter to remaining accessions #
#########################################################
$start_secs = output_progress_prior("Applying taxonomy filter", $progress_w, undef, *STDOUT);
run_command("$filter_by_taxon --input $temp_srcchk_output_file --exclude $input_tax_exclusion_file --outfile $temp_post_taxonomy_matches_file", $be_verbose);
$desc_str = sprintf("output saved as $temp_post_taxonomy_matches_file%s", opt_Get("--keep", \%opt_HH) ? "" : " (temporarily)");
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

#########################################################
# Step 6. [OPTIONAL] Remove accessions already analyzed #
#########################################################
$start_secs = output_progress_prior("Filtering out accessions already analyzed", $progress_w, undef, *STDOUT);
if (defined ($input_exclusion_acc_file)) {
    run_command("$eliminate_analyzed_acc --input $temp_post_taxonomy_matches_file --accessions $input_exclusion_acc_file --outfile $temp_post_all_filters_matches_file", $be_verbose);
}
else {
    run_command("cp $temp_post_taxonomy_matches_file $temp_post_all_filters_matches_file", $be_verbose);
}
$desc_str = "output saved as $temp_post_all_filters_matches_file";
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

####################################################################
# Step 7. Produce FASTA file of sequences for remaining accessions #
####################################################################
$start_secs = output_progress_prior("Producing FASTA file", $progress_w, undef, *STDOUT);
run_command("$get_fasta $temp_post_all_filters_matches_file $output_fasta_candidate_file", $be_verbose);
$desc_str = "output saved as $output_fasta_candidate_file";
output_progress_complete($start_secs, $desc_str, undef, *STDOUT);

####################
# Step 8. Clean up #
####################
if (!$keep_temp_files) {
    $start_secs = output_progress_prior("Cleaning up temporary intermediate output files", $progress_w, undef, *STDOUT);
    run_command("rm -f $temp_initial_matches_file",          $be_verbose); 
    run_command("rm -f $temp_initial_accessions_file",       $be_verbose); 
    run_command("rm -f $temp_Entrez_filter_script",          $be_verbose); 
    run_command("rm -f $temp_postEntrez_matches_file",       $be_verbose); 
    run_command("rm -f $temp_srcchk_output_file",            $be_verbose); 
    run_command("rm -f $temp_post_taxonomy_matches_file",    $be_verbose); 
    run_command("rm -f $temp_post_all_filters_matches_file", $be_verbose); 
    $desc_str = "deleted intermediated output files";
    output_progress_complete($start_secs, $desc_str, undef, *STDOUT);
}

#############################
# Step 9. Conclude and exit #
#############################
$total_seconds += seconds_since_epoch();
printf STDERR ("#\n");
printf STDERR ("# Final FASTA file of candidates saved to: %s\n", $output_fasta_candidate_file);

