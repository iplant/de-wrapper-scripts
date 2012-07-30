#!/usr/bin/perl -w
use strict;
use Data::Dumper;

my $find    = shift;
my $replace = shift;
my $file    = shift;
my $outname = shift;
my $casesen = shift;


($find && $replace && $file && $outname) || die "At least three arguments (find replace infile outfile) are required\n";

-e $file || die "File $file does not exist!\n";

$replace = qq/$replace/;

open IN, $file;
open OUT, ">/tmp/findreplace$$" or die $!;

while (<IN>) {
  $casesen ? s/$find/$replace/gi : s/$find/$replace/g;
  print OUT;
}

close IN;
close OUT;

system "mv /tmp/findreplace$$ $outname";
