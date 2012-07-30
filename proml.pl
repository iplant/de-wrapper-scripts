#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
use DE_util;
use Data::Dumper;

use constant BINARY => '/usr/local2/sheldon/bin/proml';

# Command line arguments for PROML (not exhaustive)
# P probability model.  [Jones-Taylor-Thornton], Henikoff/Tillier PMB, or Dayhoff PAM
# S BOOLEAN Speedier but rougher analysis (Default yes)
# G BOOLEAN Global rearrangemenes (default no)
# J Jumble input order expects random number key and number of times to jumble
# O outgroup root expects the species number (integer)
# I BOOLEAN input sequences interleaved (default yes)
# 5 BOOLEAN reconstruct hypothetical sequences (default no)
# M multiple data sets expects integer
# i non PHYLIP option for input file (required)
# c non PHYLIP option to compute consensus tree for boootstrapping

# PROML-specific option string
# Letters followed by a colon expect an argument
# Letters without a colon are BOOLEAN
my $option_string = 'cSG5IM:P:J:O:i:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

# sanity check PROML specific arguments
check_options(%opt);


# standardize name lengths
cleanup();
my $names = obfuscate_names($opt{i},'infile');


if ($opt{M}) {
    replicate($opt{M},$opt{I});
}
my $jumble = $opt{J} || 1;

# build up command file
my $stdin = '';

# random number string
my $rand = random_number_key();

$stdin .= "S\n"          unless $opt{S};
$stdin .= "O\n$opt{O}\n" if $opt{O};
$stdin .= "G\n"          if $opt{G};
$stdin .= "I\n"          unless $opt{I};
$stdin .= "5\n"          if $opt{5};
$stdin .= "J\n$rand\n$opt{J}\n" if $opt{J} && !$opt{M};
$stdin .= "M\nD\n$opt{M}\n$rand\n$jumble\n" if $opt{M};
$stdin .= "P\n"          if $opt{P} && $opt{P} =~ /Henikoff/;
$stdin .= "P\nP\n"       if $opt{P} && $opt{P} =~ /Dayhoff/;
$stdin .= "Y\n\n";

# run the job (cross you fingers!)
run($stdin,BINARY);

if ($opt{c} && $opt{M}) {
    consensus($opt{O});
    system 'perl -i -pe "s/\:[.0-9]+//g" outtree';
}


my $infile = $opt{i};
$infile =~ s/\.[^.]+$//;
deobfuscate_names('outfile',"output.txt",$names);
deobfuscate_names('outtree',"treefile.newick",$names);
cleanup();

make_treefile("treefile.newick");

# only PROML specific non BOOLEANS
sub check_options {
    my %opt = @_;
    if ($opt{P}) {
	die "Invalid choice for probability model\n" unless $opt{P} =~ /Jones|Henikoff|Dayhoff/;
    }
}
