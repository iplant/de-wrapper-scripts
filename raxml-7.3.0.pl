#!/usr/bin/perl -w
use strict;
use Getopt::Long qw(:config no_ignore_case pass_through);
use lib '/usr/local2/sheldon/lib';
use DE_util;

use constant BINARY => '/usr/local2/RAxML-7.3.0/raxmlHPC-SSE3';

my ($type,$seqfile,$model,$output);
my $rand = random_number_key();

GetOptions ( 
	     't=s' => \$type, 
	     's=s' => \$seqfile, 
	     'm=s' => \$model, 
	     'n=s' => \$output 
	     );

if ($type eq 'protein') {
    $model ||= 'PROTCAT';
    $model .= join('',@ARGV);
}
else {
    $model ||= 'GTRCAT';
}

my $cmd = BINARY . " -p $rand -s $seqfile -n $output -m $model"; 
print STDERR "Execeuting $cmd\n";
system "$cmd >output.txt";

# dirty trick to get the number of taxa
my $num = 0;
open IN, $seqfile || die "Could not open $seqfile!"; 
while (<IN>){
    if (/\s+(\d+)\s+\d+/) {
	$num = $1;
	last;
    }
}
close IN;

ntax($num);

mkdir "RAxML_out" unless -d "RAxML_out";

system "mv *.nwk *.reduced RAxML_out";
system "cp RAxML_out/RAxML_bestTree.tree.nwk treefile.newick";

make_treefile("treefile.newick");

exit 0;
