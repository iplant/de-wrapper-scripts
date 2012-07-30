#!/usr/bin/perl -w
use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

use constant TOPHATP    => '/usr/local2/tophat-1.4.1.Linux_x86_64/';
use constant BOWTIEP    => '/usr/local2/bowtie-0.12.7/';
use constant SAMTOOLSP  => '/usr/local2/samtools-0.1.18/';
use constant FORMAT     => 'SE';

# Define worflow options
my $conf_file;

my $format = FORMAT;

GetOptions("config_file=s" => \$conf_file);

chomp($ENV{PATH} = `echo \$PATH`);
$ENV{PATH} = join(':',$ENV{PATH},TOPHATP,BOWTIEP,SAMTOOLSP);

my ($conf,@query_file) = config($conf_file);

# Allow over-ride of system-level database path with user
my $fasta = $conf->{reference}->{fasta};
if (!-e "$fasta.1.ebwt") { # have to bowtie index
  unless (`grep \\> $fasta`) {
      die "Error: $fasta the user supplied file is not a FASTA file";
  }
  my $name = basename($fasta, qw/.fa .fas .fasta .fna/);
  print STDERR "bowtie-indexing $name\n";
  system BOWTIEP . "bowtie-build $fasta $name";
  $fasta = $name;
}
my $gtf = $conf->{reference}->{gtf};

my $success = undef;

mkdir "tophat_out";
for my $query_file (@query_file) {
    my $app = TOPHATP.'tophat';
    my $TOPHAT_ARGS = join(" ", @ARGV);
    if ($gtf) {
	$TOPHAT_ARGS .= " -G $gtf";
    }

    chomp(my $basename = `basename $query_file`);
    $basename =~ s/\.\S+$//;
    $basename = "tophat_out/$basename";

    my $align_command = "$app $TOPHAT_ARGS -o $basename $fasta $query_file";
    report("Executing: $align_command\n");
    system $align_command;

    $success++ if -e "$basename/accepted_hits.bam";
}

system "rm -f *.ebwt 2>/dev/null";

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}

sub version {
    1.4.1;
}

sub config {
    my $conf = shift;
    my @fastq;
    my %conf;
    my %sample;
    open CONF, $conf or die "Problem with config file $conf $!\n";
    while (<CONF>) {
	chomp;
	my ($class,$key,$val) = split;
	if ($class eq 'sample') {
	    push @{$conf{$class}->{$key}}, $val;
	    push @fastq, $val;
	    
	    # sort out bam output samples
	    chomp(my $basename = `basename $val`);
	    $basename =~ s/\.\S+$//;
	    $sample{"tophat_out/$basename"} = $key;
	}
	else {
	    $conf{$class}->{$key} = $val;
	}
    }
    close CONF;
    open CONF, ">>$conf";
    for (keys %sample) {
	print CONF join("\t",'bam',$ sample{$_}, "$_\n");
    }
    close CONF;
    return \%conf,@fastq;
}
