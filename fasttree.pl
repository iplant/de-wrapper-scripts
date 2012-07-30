#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
use DE_util;

use constant BINARY => '/usr/local2/bin/FastTree';

# Command line arguments for fastree (not exhaustive)
# i non option for input file (required)
my $option_string = 't:i:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

check_options();

my $exe = BINARY;

my $result = $opt{t} eq 'protein' ?  `$exe $opt{i} 2>FastTree_log.txt` : `$exe -gtr -nt $opt{i} 2>FastTree_log.txt`;
my $infile = $opt{i};

# get rid of numeric node labels
$result =~ s/\)[.0-9]+/\)/gm;

# dirty trick to get the number of taxa
my $num = 0;
open IN, $opt{i} || die "Could not open $opt{i}:$!"; 
my $fa;
while (<IN>){
  $fa++ if /^>/;
  $num++ if /^\S+/ && !$fa;
  $num++ if /^>/  && $fa;
}
close IN;

ntax($num);

open OUT, ">treefile.newick" or die $!;
print OUT $result;
close OUT;

make_treefile("treefile.newick");

sub check_options {
    die "must provide sequence type (dna or protein)" unless $opt{t};
    die "option t must be either 'dna' or 'protein'"  unless $opt{t} =~ /^dna|protein$/;
}
