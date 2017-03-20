#!/usr/bin/perl
#
# vecscreen_candidate_generation.pm
# Alejandro Schaffer and Eric Nawrocki
#
use strict;
use warnings;
use Time::HiRes qw(gettimeofday); # for timings

#####################################################################
# SUBROUTINES
#####################################################################
# List of subroutines:
#
# Functions for output:
# output_banner:              output the banner with info on the script and options used
# output_progress_prior:      output routine for a step, prior to running the step
# output_progress_complete:   output routine for a step, after the running the step
#
# Miscellaneous functions:
# run_command:              run a command using system()
# seconds_since_epoch:      number of seconds since the epoch, for timings
#
#################################################################
# Subroutine : output_progress_prior()
# Incept:      EPN, Fri Feb 12 17:22:24 2016 [dnaorg.pm]
#
# Purpose:      Output to $FH1 (and possibly $FH2) a message indicating
#               that we're about to do 'something' as explained in
#               $outstr.
#
#               Caller should call *this* function, then do
#               the 'something', then call output_progress_complete().
#
#               We return the number of seconds since the epoch, which
#               should be passed into the downstream
#               output_progress_complete() call if caller wants to
#               output running time.
#
# Arguments:
#   $outstr:     string to print to $FH
#   $progress_w: width of progress messages
#   $FH1:        file handle to print to, can be undef
#   $FH2:        another file handle to print to, can be undef
#
# Returns:     Number of seconds and microseconds since the epoch.
#
#################################################################
sub output_progress_prior {
    my $nargs_expected = 4;
    my $sub_name = "output_progress_prior()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }
    my ($outstr, $progress_w, $FH1, $FH2) = @_;

    if(defined $FH1) { printf $FH1 ("# %-*s ... ", $progress_w, $outstr); }
    if(defined $FH2) { printf $FH2 ("# %-*s ... ", $progress_w, $outstr); }

    return seconds_since_epoch();
}


#################################################################
# Subroutine : output_progress_complete()
# Incept:      EPN, Fri Feb 12 17:28:19 2016 [dnaorg.pm]
#
# Purpose:     Output to $FH1 (and possibly $FH2) a
#              message indicating that we've completed
#              'something'.
#
#              Caller should call *this* function,
#              after both a call to output_progress_prior()
#              and doing the 'something'.
#
#              If $start_secs is defined, we determine the number
#              of seconds the step took, output it, and
#              return it.
#
# Arguments:
#   $start_secs:    number of seconds either the step took
#                   (if $secs_is_total) or since the epoch
#                   (if !$secs_is_total)
#   $extra_desc:    extra description text to put after timing
#   $FH1:           file handle to print to, can be undef
#   $FH2:           another file handle to print to, can be undef
#
# Returns:     Number of seconds the step took (if $secs is defined,
#              else 0)
#
#################################################################
sub output_progress_complete {
    my $nargs_expected = 4;
    my $sub_name = "output_progress_complete()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }
    my ($start_secs, $extra_desc, $FH1, $FH2) = @_;

    my $total_secs = undef;
    if(defined $start_secs) {
	$total_secs = seconds_since_epoch() - $start_secs;
    }

    if(defined $FH1) { printf $FH1 ("done."); }
    if(defined $FH2) { printf $FH2 ("done."); }

    if(defined $total_secs || defined $extra_desc) {
	if(defined $FH1) { printf $FH1 (" ["); }
	if(defined $FH2) { printf $FH2 (" ["); }
    }
    if(defined $total_secs) {
	if(defined $FH1) { printf $FH1 (sprintf("%.1f seconds%s", $total_secs, (defined $extra_desc) ? ", " : "")); }
	if(defined $FH2) { printf $FH2 (sprintf("%.1f seconds%s", $total_secs, (defined $extra_desc) ? ", " : "")); }
    }
    if(defined $extra_desc) {
	if(defined $FH1) { printf $FH1 $extra_desc };
	if(defined $FH2) { printf $FH2 $extra_desc };
    }
    if(defined $total_secs || defined $extra_desc) {
	if(defined $FH1) { printf $FH1 ("]"); }
	if(defined $FH2) { printf $FH2 ("]"); }
    }

    if(defined $FH1) { printf $FH1 ("\n"); }
    if(defined $FH2) { printf $FH2 ("\n"); }

    return (defined $total_secs) ? $total_secs : 0.;
}

#####################################################################
# Subroutine: output_banner()
# Incept:     EPN, Thu Oct 30 09:43:56 2014 (rnavore)
#
# Purpose:    Output the banner with info on the script, input arguments
#             and options used.
#
# Arguments:
#    $FH:                file handle to print to
#    $version:           version
#    $releasedate:       month/year of version (e.g. "Feb 2016")
#    $synopsis:          string reporting the date
#    $date:              date information to print
#
# Returns:    Nothing, if it returns, everything is valid.
#
# Dies: never
####################################################################
sub output_banner {
    my $nargs_expected = 5;
    my $sub_name = "output_banner()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }
    my ($FH, $version, $releasedate, $synopsis, $date) = @_;

    print $FH ("\# $synopsis\n");
    print $FH ("\# version: $version ($releasedate)\n");
    print $FH ("\# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n");
    if(defined $date)    { print $FH ("# date:    $date\n"); }
    printf $FH ("#\n");

    return;
}

#################################################################
# Subroutine:  run_command()
# Incept:      EPN, Mon Dec 19 10:43:45 2016
#
# Purpose:     Runs a command using system() and exits in error
#              if the command fails. If $be_verbose, outputs
#              the command to stdout. If $FH_HR->{"cmd"} is
#              defined, outputs command to that file handle.
#
# Arguments:
#   $cmd:         command to run, with a "system" command;
#   $be_verbose:  '1' to output command to stdout before we run it, '0' not to
#
# Returns:    amount of time the command took, in seconds
#
# Dies:       if $cmd fails
#################################################################
sub run_command {
    my $sub_name = "run_command()";
    my $nargs_expected = 2;
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }

    my ($cmd, $be_verbose) = @_;

    if($be_verbose) {
      print STDERR ("Running cmd: $cmd\n");
    }

    my ($seconds, $microseconds) = gettimeofday();
    my $start_time = ($seconds + ($microseconds / 1000000.));

    system($cmd);

    ($seconds, $microseconds) = gettimeofday();
    my $stop_time = ($seconds + ($microseconds / 1000000.));

    if($? != 0) {
	die "ERROR in $sub_name, the following command failed:\n$cmd\n";
    }

    return ($stop_time - $start_time);
}

#################################################################
# Subroutine : seconds_since_epoch()
# Incept:      EPN, Sat Feb 13 06:17:03 2016
#
# Purpose:     Return the seconds and microseconds since the
#              Unix epoch (Jan 1, 1970) using
#              Time::HiRes::gettimeofday().
#
# Arguments:   NONE
#
# Returns:     Number of seconds and microseconds
#              since the epoch.
#
#################################################################
sub seconds_since_epoch {
    my $nargs_expected = 0;
    my $sub_name = "seconds_since_epoch()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }

    my ($seconds, $microseconds) = gettimeofday();
    return ($seconds + ($microseconds / 1000000.));
}

#################################################################
# Subroutine : parse_filelist_file()
# Incept:      EPN, Thu Mar 16 14:21:52 2017
#
# Purpose:     Parse the file $filelist_file by saving each line 
#              as an element in @AR, after verifying that the file
#              listed on that line actually exists. The file can
#              exist as either a relative path (in which case we 
#              prepend the current working directory) or an 
#              absolute path.
#
# Arguments:   
#   $filelist_file: name of file to open and read from
#   $AR:            ref to array to fill with file names
#
# Returns:     Number of files/lines read
#
# Dies:        If any file listed in the $filelist_file does not
#              exist.
#
#################################################################
sub parse_filelist_file { 
    my $nargs_expected = 2;
    my $sub_name = "parse_filelist_file()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); }

    my ($filelist_file, $AR) = @_;

    my $directory;          #current directory
    my $count;              #count of files
    my $relname;            #relative path name of an input fasta file
    my $absname;            #absolute path name of an input fasta file
    my $nextline;           #one line of the input file
    my $errmsg;             #error message used in case we have to die

    $directory = cwd() . "/";
    $count = 0;
    $errmsg = "";

    open(IN, "<", $filelist_file) or die "ERROR in $sub_name, unable to open $filelist_file for reading"; 

    while(defined($nextline = <IN>)) {
      chomp($nextline);
      $relname = $directory . $nextline;
      $absname = $nextline;
      if(-e $relname) { 
        $AR->[$count] = $relname;
      }
      elsif(-e $absname) { 
        $AR->[$count] = $absname;
      }
      else { 
        $errmsg .= "$nextline\n";
      }
      $count++;
    }
    close(IN);
    if($errmsg ne "") { 
      die "ERROR in $sub_name, the following files listed in $filelist_file do not exist (as relative paths or absolute paths):\n$errmsg\n";
    }

    return $count;
}

####################################################################
# the next line is critical, a perl module must return a true value
return 1;
####################################################################
