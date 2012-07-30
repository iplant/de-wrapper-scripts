#!/usr/bin/perl -w
use strict;
use Getopt::Long qw(:config pass_through);

use constant CUFFLINKS  => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/';

# Define worflow options
my ($config_file);

GetOptions( 'config_file:s' => \$config_file );	   

my ($conf)     = config($config_file);
my $query_dir  = $conf->{output}->{cufflinks};
my $merge_file = "$query_dir/gtf_to_merge.txt";
-e $merge_file || die <<END;
This implementation of cuffmerge is designed to be run as part of a workflow.
The expected file $merge_file from the previous cufflinks step was not found.
END
;

my $gtf   = $conf->{reference}->{gtf};
my $fasta = $conf->{reference}->{fasta};

my $CUFFARGS = join(" ", @ARGV); 
my $cmd = CUFFLINKS . "cuffmerge $CUFFARGS -o $conf->{output}->{cuffmerge}";
$cmd .= " -g $gtf"   if $gtf;
$cmd .= " -s $fasta" if $fasta;
$cmd .= " $merge_file";

report("Executing: $cmd");

system ($cmd);

my $success = -e "cuffmerge_out/transcripts.gtf";

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}


sub config {
    my $conf = shift;
    my @fastq;
    my %conf;
    open CONF, $conf or die "Problem with config file $conf $!\n";
    while (<CONF>) {
        chomp;
	my ($class,$key,$val) = split;
        if ($class eq 'sample') {
            push @{$conf{$class}->{$key}}, $val;
            push @fastq, $val;
        }
        else {
            $conf{$class}->{$key} = $val;
        }
    }
    return \%conf,@fastq;
}
