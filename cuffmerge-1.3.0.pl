#!/usr/bin/perl -w
use strict;
use Getopt::Long;

use constant CUFFLINKS  => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/';

# Define worflow options
my ($query_dir, $anno_database, $user_anno_database, $seq_database, $user_seq_database, $p, $version, $minisofrac);

GetOptions(	   
		   "indir=s"           => \$query_dir,
		   "user_annotation=s" => \$user_anno_database,
		   "annotation=s"      => \$anno_database,
		   "user_database=s"   => \$user_seq_database,
		   "database=s"        => \$seq_database,
		   "p=i"               => \$p,
		   "version=s"         => \$version,
		   "min-isoform-fraction=s" => \$minisofrac            
		   );

unless (-d $query_dir) {
    die "A query folder is required";
}

# user supplied annotations/seqs trump the canned ones
if ($user_anno_database) {
    $anno_database = $user_anno_database;
}
if ($user_seq_database) {
    $seq_database = $user_seq_database;
}

$p ||= 8;

my $merge_file = "$query_dir/gtf_to_merge.txt";

-e $merge_file || die <<END;
This implementation of cuffmerge is designed to be run as part of a workflow.
The expected files $query_dir/gtf_to_merge.txt from the previous cufflinks
step was not found.
END
;
 

my $cmd = CUFFLINKS . "cuffmerge -p $p -o cuffmerge_out";
$cmd .= " -g $anno_database" if $anno_database;
$cmd .= " -s $seq_database " if $seq_database;
$cmd .= " --min-isoform-fraction $minisofrac " if $minisofrac;
$cmd .= " $query_dir/gtf_to_merge.txt";

report("Executing: $cmd");

system ($cmd);

my $success = -e "cuffmerge_out/transcripts.gtf";

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}

