#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
use DE_util;
use Data::Dumper;

use constant ANNOTATIONS  => '/usr/local2/ensembl_plant_gene_desc/';
use constant MINFOLD      => 2;

my $option_string = 'af:i:p:s:d:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

my (%desc);
my $how_sort  = shift  || 'fold_change';
my $want_desc = shift;
my $min_fold  = $opt{f} || MINFOLD;
my $max_p     = $opt{p} || 0;
my $infile    = $opt{i};
my $asc       = $opt{a};

$want_desc = ANNOTATIONS . "$want_desc.13.gz" if $want_desc;
$want_desc = '' if $want_desc eq 'null';
if ($want_desc && -e $want_desc) {
    open DEF, "zcat $want_desc |" or die $!;
    while (<DEF>) {
	chomp;
	my ($g,$l,$d) = split "\t";
	$g or next;
	$desc{$g}  = $d || '.';
    }
    close DEF;
}
elsif ($want_desc) {
    open OUT, ">warning.txt";
    print OUT "$want_desc was not found!\n";
    close OUT;
}

#print Dumper \%desc;

open IN, $infile or die $!;
my ($out,@out);
while (<IN>) {
    next if /test_id/;
    next unless /OK/;
    my @line = split "\t";
    my $gene = $line[1];
    my $locus = $line[2];
    $gene =~ s/,\S+//;
    my $direction =$line[7] > $line[8] ? 'DOWN' : 'UP';
    my ($hi,$lo) = sort { $b <=> $a } $line[7], $line[8];
    next unless $hi && $lo;
    my $fold_change = $hi/$lo;
    next if $fold_change < $min_fold;
    my $p_val = $line[12];
    next if $max_p && $p_val > $max_p;
    my $out = join ("\t",$hi+$lo,$fold_change,$gene,$locus||'.',sprintf("%.2f",$fold_change),$direction,$p_val);
    if ($want_desc && defined $desc{$gene}) {
	$out .= "\t$desc{$gene}";
    }
    push @out, $out;
}
close IN;

my @print;
my $index = $how_sort =~ /fold/ ? '2n' : '1n';
$index .= 'r' unless $asc;

open OUT, ">gene_list.txt";
print OUT  join("\t",qw/gene_id gene_name fold_change 
                        direction q-value gene_description/) . "\n";
open OUT, "| sort -k$index | cut --complement -f1,2 >>gene_list.txt";
print OUT join("\n", @out);
close OUT;

exit 0;
__END__

