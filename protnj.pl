#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
use DE_util;
use File::Copy;
use Data::Dumper;
use constant DIST     => '/usr/local2/sheldon/bin/protdist';
use constant BINARY   => '/usr/local2/sheldon/bin/neighbor';

# Command line arguments
# P Distance [Jones-Taylor-Thornton matrix], Henikoff/Tillier PMB matrix, 
#   Dayhoff PAM matrix, Kimura formula, Similarity table
# O outgroup root expects the species number (integer)
# I BOOLEAN input sequences interleaved (default yes)
# i non PHYLIP option for input file (required)

# Letters followed by a colon expect an argument
# Letters without a colon are BOOLEAN
my $option_string = 'IcP:O:i:M:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

# sanity check PROML specific arguments
check_options(%opt);

cleanup();

# standardize name lengths
my $names = obfuscate_names($opt{i},'infile');


#bootstrapping
if ($opt{M}) {
    replicate($opt{M},$opt{I});
}

# build up command file
my $stdin = '';

# first we need to deal with distance matrix
$stdin .= "P\n"          if $opt{P} && $opt{P} =~ /Henikoff/;
$stdin .= "P\nP\n"       if $opt{P} && $opt{P} =~ /Dayhoff/;
$stdin .= "P\nP\nP\n"    if $opt{P} && $opt{P} =~ /Kimura/;
$stdin .= "P\nP\nP\nP\n" if $opt{P} && $opt{P} =~ /Similarity/;
$stdin .= "M\nD\n$opt{M}\n" if $opt{M};
$stdin .= "I\n"          unless $opt{I};
$stdin .= "Y\n\n";

run($stdin,DIST);

move('outfile', 'distance.fel');
cleanup();
move('distance.fel', 'infile');

my $rand = random_number_key();

# Now neighbor
$stdin  = '';
$stdin .= "M\n$opt{M}\n$rand\n" if $opt{M};
$stdin .= "O\n$opt{O}\n" if $opt{O};
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

# only dnadist specific non BOOLEANS
sub check_options {
    my %opt = @_;
    if ($opt{P}) {
	die "Invalid choice ($opt{P}) for distance model\n" unless $opt{P} =~ /Jones|Henikoff|Dayhoff|Similarity|Kimura/;
    }
}
