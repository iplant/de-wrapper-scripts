#!/usr/bin/perl -w
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

# Define worflow options                                                                                                                                    
my ($root, $fastq, $fasta, $gtf, @query_file);

GetOptions( "fastq:s" => \$fastq,
            "fasta:s" => \$fasta,
            "gtf:s"   => \$gtf,
            "root:s"  => \$root);

$fastq && $root  && $fasta && $gtf || die "All options (fastq && roots && fasta && gtf) are required\n";


if (-d $fastq) {
    while (<$fastq/*>) {
	push @query_file, $_;
    }
}
if (!@query_file) {
    die "Error: no fastq file(s) specified!\n";
}
my @names = split(',',$root);
my %names;
for my $name (@names) {
    $names{$name} = [grep {/^$name|\/$name/} @query_file];
}
unless (%names) {
    die "No input files (@query_file) matches the root names (@names)!\n";
}
unless (-e $gtf) {
    die "No reference annotation file was supplied!\n";
}
unless (-e $fasta) {
    die "No reference sequence file was supplied!\n";
}

open OUT, ">Tuxedo_config.txt";

for my $k (keys %names) {
    print OUT join("\t",'sample',$k,$_),"\n" for @{$names{$k}};
}

print OUT join("\t",qw/reference fasta/,$fasta), "\n";
print OUT join("\t",qw/reference gtf/,$gtf), "\n";
print OUT join("\t",qw/output tophat tophat_out/), "\n";
print OUT join("\t",qw/output cufflinks cufflinks_out/), "\n";
print OUT join("\t",qw/output cuffmerge cuffmerge_out/), "\n";
print OUT join("\t",qw/output cuffdiff cuffdiff_out/), "\n";

for my $k (keys %names) {
    print OUT join("\t",'sample',$k,$_),"\n" for @{$names{$k}};
}

close OUT;
