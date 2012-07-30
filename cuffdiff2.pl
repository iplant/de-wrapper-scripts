#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config);
use Data::Dumper;

my $num_threads = 6;
my $time_series = 0;
my $upper_quartile_norm = 0;
my $total_hits_norm = 0;
my $compatible_hits_norm = 1;
my $frag_bias_correct = '';
my $multi_read_correct = 0;
my $min_alignment_count = 10;
my $mask_file = '';
my $fdr = '0.05';
my $cannedReference = '';
my (@sampleOne,@sampleTwo,@sampleThree,@sampleFour,@sampleFive,@sampleSix,@sampleSeven,@sampleEight,@sampleNine,@sampleTen);
my ($nameOne,$nameTwo,$nameThree,$nameFour,$nameFive,$nameSix,$nameSeven,$nameEight,$nameNine,$nameTen);



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
			  'cannedReference=s'     => \$cannedReference,
			  'userReference=s'       => \$userReference,
			  'sampleOne=s'           => \@sampleOne,
			  'sampleTwo=s'           => \@sampleTwo,
                          'sampleThree:s'         => \@sampleThree,
                          'sampleFour:s'          => \@sampleFour,
                          'sampleFive:s'          => \@sampleFive,
                          'sampleSix:s'           => \@sampleSix,
                          'sampleSeven:s'         => \@sampleSeven,
                          'sampleEight:s'         => \@sampleEight,
                          'sampleNine:s'          => \@sampleNine,
                          'nameTen:s'             => \$nameTen,
                          'nameOne=s'             => \$nameOne,
                          'nameTwo=s'             => \$nameTwo,
                          'nameThree:s'           => \$nameThree,
                          'nameFour:s'            => \$nameFour,
                          'nameFive:s'            => \$nameFive,
                          'nameSix:s'             => \$nameSix,
                          'nameSeven:s'           => \$nameSeven,
                          'nameEight:s'           => \$nameEight,
                          'nameNine:s'            => \$nameNine,
                          'nameTen:s'             => \$nameTen,
);

# Annotation sanity check
unless ($cannedReference || $userReference) {
    die "Reference or custom annotations must be supplied for CuffDiff\n";
}

# Custom trumps canned
if ($userReference) {
    $cannedRefence = $userReference
}

my $cmd = "/usr/local2/bin/cuffdiff --num-threads $num_threads --min-alignment-count $min_alignment_count --FDR $fdr ";

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


# get rid of empty labels (assumes in order)
my @labels = grep {$_} ($nameOne,$nameTwo,$nameThree,$nameFour,$nameFive,$nameSix,$nameSeven,$nameEight,$nameNine,$nameTen);
if (@labels) {
  $cmd .= ' --labels '.join(',',@labels).' ';
}

# Append GTF file
$cmd .= "$cannedReference ";

for (\@sampleOne,\@sampleTwo,\@sampleThree,\@sampleFour,\@sampleFive,\@sampleSix,\@sampleSeven,\@sampleEight,\@sampleNine,\@sampleTen) {
  if ($_ && @$_ == 1) {
      if (-d $_->[0]) {
	  my $d = shift @$_;
	  while (my $f = <$d/*>) {
	      push @$_, $f
	  }
      }
  } 

  $cmd .= ' '.join(',',@$_) if @$_;
}

print STDERR $cmd, "\n";

system($cmd);
