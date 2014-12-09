#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;

use constant CUFFLINKS  => ('1.3.0' => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/',
                            '2.0.2' => '/usr/local2/cufflinks-2.0.2.Linux_x86_64/',
                            '2.1.1' => '/usr/local2/cufflinks-2.1.1.Linux_x86_64/',
                            '2.2.0' => '/usr/local2/cufflinks-2.2.0.Linux_x86_64/');

report_input_stack();

my ($query_dir, $anno_database, $user_anno_database, $seq_database, $user_seq_database, 
    $p, $version, $minisofrac, @infile);

GetOptions(	   
		   "indir=s"           => \$query_dir,
		   "infile=s"          => \@infile,
		   "user_annotation=s" => \$user_anno_database,
		   "annotation=s"      => \$anno_database,
		   "user_database=s"   => \$user_seq_database,
		   "database=s"        => \$seq_database,
		   "p=i"               => \$p,
		   "version=s"         => \$version,
		   "min-isoform-fraction=s" => \$minisofrac            
		   );

unless ($query_dir || @infile > 0) {
    die "A query folder or list of files  required";
}

# user supplied annotations/seqs trump the canned ones
if ($user_anno_database) {
    $anno_database = $user_anno_database;
}
if ($user_seq_database) {
    $seq_database = $user_seq_database;
}

$p ||= 8;

my $merge_file;
if ($query_dir) {
    $merge_file = "$query_dir/gtf_to_merge.txt";
}
else {
    $merge_file = "gtf_to_merge.txt";
    open OUT, ">$merge_file" or die $!;
    print OUT join("\n",@infile), "\n";
    close OUT;
}

-e $merge_file || die <<END;
This implementation of cuffmerge is designed to be run as part of a workflow.
The expected files $query_dir/gtf_to_merge.txt from the previous cufflinks
step was not found.
END
;
 
my %ver = CUFFLINKS;
my $cufflinksp = $ver{$version} || die "Version $version of Cufflinks is not supported\n";
chomp($ENV{PATH} = `echo \$PATH`);
$ENV{PATH} = join(':',$ENV{PATH},$cufflinksp);

my $cmd = 'cuffmerge -o cuffmerge_out';
$cmd .= " -g $anno_database " if $anno_database;
$cmd .= " -s $seq_database "  if $seq_database;
$cmd .= " --min-isoform-fraction $minisofrac " if $minisofrac;
$cmd .= " $merge_file ";


report("Executing: $cmd");

system ($cmd);

system "rm -f $merge_file";

my $success = -e "cuffmerge_out/merged.gtf";


# convert the merged GTF into form that uses the original Transcript IDs

open ANN, $anno_database or die $!;
my (%transcript2gene,%gene2alias);
while (<ANN>) {
    chomp;
    my ($gene_id) = /gene_id "([^\"]+)"/;
    my ($transcript_id) = /transcript_id "([^\"]+)"/;
    my ($alias) = /gene_name "([^\"]+)"/;
    $transcript2gene{$transcript_id} = $gene_id if $transcript_id;
    $gene2alias{$gene_id} = $alias if $alias;
}

open GTF, "cuffmerge_out/merged.gtf" or die $!;
open OUT, ">cuffmerge_out/merged_with_ref_ids.gtf" or die $!;

while (<GTF>) {
    chomp;
    my @gff  = split "\t";
    my $atts = pop @gff;
    my @atts = split('; ',$atts);
    my %atts = map {split} grep {s/\"|;//g} @atts;
    my ($class_code) = $atts{class_code} =~ /[=j]/;
    if ($class_code) {
	my ($oid) = $atts{oId};
	my ($tid) = $atts{nearest_ref} || 'null';
	my $gid = $transcript2gene{$tid} || $atts{gene_name};
	if ($gid) {
	    $atts{gene_id} = $gid;
	    $atts{gene_name} = $gene2alias{$gid} if $gene2alias{$gid};
	}
	if ($oid) {
	    $atts{transcript_id} = $oid;
	    delete $atts{oId};
	}
    }

    $atts = "gene_id $atts{gene_id}";
    delete $atts{gene_id};
    for my $k (keys %atts) {
	$atts .= "; $k \"$atts{$k}\"";
    }
    $gff[8] = $atts;

    print OUT join("\t",@gff), "\n";
}
close OUT;
close GTF;

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}

sub report_input_stack {
    my @stack = @ARGV;
    my %arg;

    while (@stack) {
        my $k = shift @stack;
	my $v = shift @stack;
        if ($v =~ /^-/) {
            unshift @stack, $v;
            $v = 'TRUE';
	}
        push @{$arg{$k}}, $v;
    }

    report("Input parameters:");
    for (sort keys %arg) {
        report(sprintf("%-25s",$_) . join(',',@{$arg{$_}}));
    }
}


