#!/bin/tcsh
#$ -P unified

# list resource request options
#$ -l h_vmem=32G,reserve_mem=32G,mem_free=32G

# split stdout and stderr files (default is they are joined into one file)
#$ -j n

# job is re-runnable if SGE fails while it's running (e.g. the host reboots)
#$ -r y
# stop email from being sent at the end of the job
#$ -m n

# trigger NCBI facilities so runtime enviroment is similar to login environment
#$ -v SGE_FACILITIES

#define stderr file
#$ -e blastrun_2.err
# define stdout file
#$ -o blastrun_2.out
echo "starting blastn"

/usr/bin/blastn -word_size 20 -ungapped -query /panfs/pan1.be-md.ncbi.nlm.nih.gov/infernal/notebook/17_0315_vecscreen_candidate_code_review/epn-2017.01.24/testfiles/A13776.1:1-42.na -db nr -show_gis -perc_identity 96 -xdrop_ungap 4 -dust no -outfmt " 6 qaccver sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore" -out /panfs/pan1.be-md.ncbi.nlm.nih.gov/infernal/notebook/17_0315_vecscreen_candidate_code_review/epn-2017.01.24/results2.out
