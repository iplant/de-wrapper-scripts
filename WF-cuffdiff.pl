#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config);
use Data::Dumper;

use constant PATH   => '/usr/local3/bin/cufflinks-1.3.0.Linux_x86_64';
use constant BINARY => 'cuffdiff';

my $num_threads          = 6;
my $time_series          = '';
my $upper_quartile_norm  = '';
my $total_hits_norm      = '';
my $compatible_hits_norm = 1;
my $frag_bias_correct    = 0;
my $multi_read_correct   = '';
my $min_alignment_count  = 10;
my $mask_file            = '';
my $fdr                  = '0.05';
my $config_file          = '';
my $gtf                  = '';
my $result = GetOptions (
                          'num-threads=i'         => \$num_threads,
                          'time-series'           => \$time_series,
                          'upper-quartile-norm'   => \$upper_quartile_norm,
                          'total-hits-norm'       => \$total_hits_norm,
                          'compatible-hits-norm'  => \$compatible_hits_norm,
                          'frag-bias-correct:s'   => \$frag_bias_correct,
                          'multi-read-correct'    => \$multi_read_correct,
                          'min-alignment-count=i' => \$min_alignment_count,
                          'mask-file:s'           => \$mask_file,
                          'FDR:s'                 => \$fdr,
			  'config_file:s'         => \$config_file,
			  'g:s'                   => \$gtf,
);

my ($conf,@labels) = config($config_file);

$gtf ||= $conf->{reference}->{gtf};
my $cuffmerge_out = $conf->{output}->{cuffmerge};
my $merged_gtf = "$cuffmerge_out/transcripts.gtf";
my $fasta      = $conf->{refererence}->{fasta};

my @samples;
for my $label (@labels) {
    push @samples, join(',',@{$conf->{bam}->{$label}});
}
my $samples = join(' ',@samples);


my $cmd = PATH . "/" . BINARY;
$cmd .= " --num-threads $num_threads --min-alignment-count $min_alignment_count --FDR $fdr ";

if ($frag_bias_correct ne '') {
	$cmd .= "--frag-bias-correct $frag_bias_correct ";
}

if ($mask_file ne '') {
	$cmd .= "--mask-file $mask_file ";
}

if ($time_series) {
	$cmd .= "--time-series "
}
if ($upper_quartile_norm) {
	$cmd .= "--upper-quartile-norm "
}
if ($total_hits_norm) {
	$cmd .= "--total-hits-norm "
}
if ($compatible_hits_norm) {
	$cmd .= "--compatible-hits-norm "
}
if ($multi_read_correct) {
	$cmd .= "--multi-read-correct "
}


$cmd .= '-u  --labels '.join(',',@labels).' ';

#$cmd .= "-g $conf->{reference}->{gtf} ";

$cmd .= "-b $conf->{reference}->{fasta} ";

$cmd .= "$merged_gtf "; 

$cmd .= $samples;

report("executing: $cmd");

system($cmd);

sub report {
    print STDERR "$_[0]\n";
}


sub config {
    my $conf = shift;
    my @labels;
    my %conf;
    open CONF, $conf or die "Problem with config file $conf $!\n";
    while (<CONF>) {
        chomp;
	my ($class,$key,$val) = split;
        if ($class eq 'sample') {
            push @{$conf{$class}->{$key}}, $val;
        }
	elsif ($class eq 'bam') {
            push @{$conf{$class}->{$key}}, $val;
	}
        else {
            $conf{$class}->{$key} = $val;
        }
    }
    @labels= keys %{$conf{bam}};
    return \%conf,@labels;
}
