#!/usr/bin/perl -w
# the first line of perl code has to be above
#
# Script to test the candidate generation pipeline for vecscreen.
# 
# Usage: test-scripts.pl
#
# Must be run from directory with the following required files:
#
use strict;

require "vecscreen_candidate_generation.pm";

####################################################################
# Test generate_run_blast_scripts.pl
####################################################################
# make sure executable scripts exist:
foreach my $req_exec ("generate_run_blast_scripts.pl") { 
  if(! -s $req_exec) { 
    die "ERROR required executable $req_exec does not exist in current directory";
  }
}

my $noutput = 4;
my @exp_outputfile_A = ();
my @outputfile_A = ();
my @inputfile_A = ();
push(@exp_outputfile_A, "test-files/expected.mytest0.csh");
push(@exp_outputfile_A, "test-files/expected.mytest1.csh");
push(@exp_outputfile_A, "test-files/expected.mytest2.csh");
push(@exp_outputfile_A, "test-files/expected.mytestqsubscript");

push(@outputfile_A, "mytest0.csh");
push(@outputfile_A, "mytest1.csh");
push(@outputfile_A, "mytest2.csh");
push(@outputfile_A, "mytestqsubscript");

push(@inputfile_A, "test-files/input.univec_list.txt");

# make sure required expected output files exist to compare against
foreach my $req_file (@exp_outputfile_A) { 
  if(! -s $req_file) { 
    die "ERROR required file $req_file to compare output against does not exist";
  }
}
# make sure required input files exist 
foreach my $req_file (@inputfile_A) { 
  if(! -s $req_file) { 
    die "ERROR required input file $req_file does not exist";
  }
}

# remove any output files that currently exist 
foreach my $outputfile (@outputfile_A) { 
  if(-e $outputfile) { run_command("rm $outputfile", 0); }
}

my $diff_output;
my $cmd = "./generate_run_blast_scripts.pl --wait --input test-files/input.univec_list.txt --outprefix mytest > /dev/null";
run_command($cmd, 1);
for(my $i = 0; $i < $noutput; $i++) { 
  if(! -e $outputfile_A[$i]) { 
    die "ERROR expected output file $outputfile_A[$i] was not created"; 
  }
  printf STDERR ("Checking output file %d $outputfile_A[$i] ... ", $i+1);
  if($outputfile_A[$i] =~ m/\.csh/) { 
    # a qsub blast command, we can't use 'diff' because we expect differences in paths
    $diff_output = compare_blast_qsub_scripts($outputfile_A[$i], $exp_outputfile_A[$i]);
    if($diff_output ne "") { 
      die "\nERROR expected output file $outputfile_A[$i] not identical to $exp_outputfile_A[$i]\nEven after removing paths\nDifferences from manual diff:\n$diff_output"; 
    }
  }
  else { 
    $diff_output = `diff $outputfile_A[$i] $exp_outputfile_A[$i]`;
    if($diff_output ne "") { 
      die "\nERROR expected output file $outputfile_A[$i] not identical to $exp_outputfile_A[$i]\nDifferences from diff:\n$diff_output"; 
    }
  }
  printf STDERR ("done.\n");
}

# clean up by removing output files we just created
foreach my $outputfile (@outputfile_A) { 
  if(-e $outputfile) { run_command("rm $outputfile", 0); }
}

####################################################################
# Test filter_vgenerate_run_blast_scripts.pl
####################################################################
# make sure executable scripts exist:
foreach my $req_exec ("filter_vecscreen_candidates.pl") { 
  if(! -s $req_exec) { 
    die "ERROR required executable $req_exec does not exist in current directory";
  }
}

$noutput = 7;
@exp_outputfile_A = ();
@outputfile_A = ();
@inputfile_A = ();
push(@exp_outputfile_A, "test-files/expected.initial_candidate_matches.txt");
push(@exp_outputfile_A, "test-files/expected.initial_candidate_short_acc.txt");
push(@exp_outputfile_A, "test-files/expected.postEntrez_candidate_accessions.txt");
push(@exp_outputfile_A, "test-files/expected.taxonomy_info.txt");
push(@exp_outputfile_A, "test-files/expected.post_taxonomy_candidate_accessions.txt");
push(@exp_outputfile_A, "test-files/expected.post_all_filters_candidate_accessions.txt");
push(@exp_outputfile_A, "test-files/expected.mytest.fa");

push(@outputfile_A, "initial_candidate_matches.txt");
push(@outputfile_A, "initial_candidate_short_acc.txt");
push(@outputfile_A, "postEntrez_candidate_accessions.txt");
push(@outputfile_A, "taxonomy_info.txt");
push(@outputfile_A, "post_taxonomy_candidate_accessions.txt");
push(@outputfile_A, "post_all_filters_candidate_accessions.txt");
push(@outputfile_A, "mytest.fa");

push(@inputfile_A, "test-files/input.blast_list.txt");
push(@inputfile_A, "test-files/input.filter_list.txt");
push(@inputfile_A, "test-files/input.excluded_taxa.txt");
push(@inputfile_A, "test-files/input.excluded_accessions.txt");

# make sure required expected output files exist to compare against
foreach my $req_file (@exp_outputfile_A) { 
  if(! -s $req_file) { 
    die "ERROR required file $req_file to compare output against does not exist";
  }
}
# make sure required input files exist 
foreach my $req_file (@inputfile_A) { 
  if(! -s $req_file) { 
    die "ERROR required input file $req_file does not exist";
  }
}

# remove any output files that currently exist 
foreach my $outputfile (@outputfile_A) { 
  if(-e $outputfile) { run_command("rm $outputfile", 0); }
}

$cmd = "./filter_vecscreen_candidates.pl --keep --input_match_files test-files/input.blast_list.txt --input_filters_file test-files/input.filter_list.txt --input_tax_exclusion_file test-files/input.excluded_taxa.txt --input_exclude_accessions test-files/input.excluded_accessions.txt --output mytest.fa > /dev/null";
run_command($cmd, 1);
for(my $i = 0; $i < $noutput; $i++) { 
  if(! -e $outputfile_A[$i]) { 
    die "ERROR expected output file $outputfile_A[$i] was not created"; 
  }
  printf STDERR ("Checking output file %d $outputfile_A[$i] ... ", $i+1);
  my $diff_output = `diff $outputfile_A[$i] $exp_outputfile_A[$i]`;
  if($diff_output ne "") { 
    die "\nERROR expected output file $outputfile_A[$i] not identical to $exp_outputfile_A[$i]\nDifferences from diff:\n$diff_output"; 
  }
  printf STDERR ("done.\n");
}

# clean up by removing output files we just created
foreach my $outputfile (@outputfile_A) { 
  if(-e $outputfile) { run_command("rm $outputfile", 0); }
}
###############################################################

printf("SUCCESS: all output files were as expected.\n");

#################################################################
# Subroutine : compare_blast_qsub_scripts()
# Incept:      EPN, Fri Mar 17 10:25:21 2017
#
# Purpose:     Compare two files that are blast qsub scripts output
#              from generate_run_blast_scripts.pl. We can't just
#              diff these files against each other because they include
#              directory paths that are expected to differ between
#              a local install and the test-files included with the
#              program.
#
# Arguments:   
#   $file1:    BLAST qsub script 1
#   $file2:    BLAST qsub script 2
#
# Returns:     Difference between the files, as a string if the
#              files have the same number of lines.
#
# Dies:        If unable to open $file1 or $file2. If files
#              have a different number of lines.
#
#################################################################
sub compare_blast_qsub_scripts { 
    my $nargs_expected = 2;
    my $sub_name = "compare_blast_qsub_scripts()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }

    my ($file1, $file2) = @_;

    # determine number of lines in each file first, they should be equal
    my $nlines1 = 0;
    my $nlines2 = 0;
    my $line1;
    my $line2;
    open(IN1, "<", $file1) or die "ERROR in $sub_name, unable to open $file1 for reading"; 
    while($line1 = <IN1>) { 
      $nlines1++;
    }
    close(IN1);
    open(IN2, "<", $file2) or die "ERROR in $sub_name, unable to open $file2 for reading"; 
    while($line2 = <IN2>) { 
      $nlines2++;
    }
    close(IN2);

    if($nlines1 != $nlines2) { 
      die "ERROR in $sub_name, two files $file1 and $file2 expected to be identical differ in number of lines"; 
    }

    # Pass 2: go through each file and make sure each line is identical
    #         UNLESS it is a blastn command, in which case the -query argument
    #         and the -out argument can differ.
    # (If we get here we know the two files have the same number of lines)
    open(IN1, "<", $file1) or die "ERROR in $sub_name, unable to open $file1 for reading (pass 2)"; 
    open(IN2, "<", $file2) or die "ERROR in $sub_name, unable to open $file2 for reading (pass 2)"; 
    my $line_ct = 0;
    my $diff_str = "";
    while($line1 = <IN1>) { 
      $line2 = <IN2>;
      $line_ct++;
      if($line1 =~ /^\/usr\/bin\/blastn/) { 
        if($line2 !~ /^\/usr\/bin\/blastn/) { 
          die "ERROR in $sub_name, two files $file1 and $file2 expected to be identical differ in placement of blast command"; 
        }
        $line1 =~ s/\-query\s+\S+//;
        $line1 =~ s/\-out\s+\S+//;
        $line2 =~ s/\-query\s+\S+//;
        $line2 =~ s/\-out\s+\S+//;
      }
      if($line1 ne $line2) {
        $diff_str .= $line_ct . "c" . $line_ct . "\n";
        $diff_str .= "< $line1";
        $diff_str .= "---manual-diff---\n";
        $diff_str .= "> $line2";
      }
    }
    close(IN1);
    close(IN2);

    return $diff_str;
}
