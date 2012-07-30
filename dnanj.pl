#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
#use lib "/home/smckay/DE/lib";
use DE_util;
use File::Copy;

use constant DIST     => '/usr/local2/sheldon/bin/dnadist';
use constant BINARY   => '/usr/local2/sheldon/bin/neighbor';

# Command line arguments
# D Distance [F84] 'Kimura 2-parameter' Jukes-Cantor LogDet 'Similarity table'
# T transition/transversion ratio expects a float value (default 2.0000)
# F user defined base frequencies (default empirical)
# O outgroup root expects the species number (integer)
# I BOOLEAN input sequences interleaved (default yes)
# i non PHYLIP option for input file (required)
# Letters followed by a colon expect an argument
# Letters without a colon are BOOLEAN

my $option_string = 'IcD:T:F:O:i:M:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

# sanity check DNANJ specific arguments
check_options(%opt);

cleanup();

# standardize name lengths
my $names = obfuscate_names($opt{i},'infile');

# bootstrapping
if ($opt{M}) {
    replicate($opt{M},$opt{I});
}

# build up command file
my $stdin = '';

# first we need to deal with distance matrix
$stdin .= "D\n"          if $opt{D} && $opt{D} =~ /Kimura/;
$stdin .= "D\nD\n"       if $opt{D} && $opt{D} =~ /Jukes/;
$stdin .= "D\nD\nD\n"    if $opt{D} && $opt{D} =~ /LogDet/;
$stdin .= "D\nD\nD\nD\n" if $opt{D} && $opt{D} =~ /Similarity/;
$stdin .= "T\n$opt{T}\n" if $opt{T} && $opt{D} =~ /Kimura|F84/;
$stdin .= "F\n$opt{F}\n" if $opt{F};
$stdin .= "M\nD\n$opt{M}\n" if $opt{M};
$stdin .= "I\n"          unless $opt{I};
$stdin .= "Y\n\n";

warn "STDIN DIST:\n$stdin";

run($stdin,DIST);

move('outfile', 'distance.fel');
cleanup();
move('distance.fel', 'infile');


# Now neighbor
my $rand = random_number_key(); 
$stdin  = '';
$stdin .= "O\n$opt{O}\n" if $opt{O};
$stdin .= "M\n$opt{M}\n$rand\n" if $opt{M};
$stdin .= "Y\n\n";

# run the job (cross you fingers!)
run($stdin,BINARY);


if ($opt{c} && $opt{M}) {
    consensus($opt{O});
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
    if ($opt{D}) {
	die "Invalid choice ($opt{D}) for distance model\n" unless $opt{D} =~ /Kimura|Jukes|LogDet|Similarity|F84/;
    }
}
