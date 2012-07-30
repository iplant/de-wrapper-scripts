#!/usr/bin/env perl
use strict;

use constant TEMPFILE   => 'muscle.alignment.phylip.tmp';
use constant FINALFILE  => 'phylip_interleaved.aln';
use constant EXECUTABLE => '/usr/local2/muscle3.8.31/muscle';

my ( $fasta, $seqtype ) = @ARGV;
$fasta && $seqtype or die "fasta file and sequence types required!\n";

my $arguments = "-in $fasta -seqtype $seqtype -phyiout ".TEMPFILE.
                " -physout phylip_sequential.aln ".
                "-fastaout fasta.aln -clwout clustalw.aln";

my %seen_label;
open IN, $fasta or die "could not open $fasta: $!"; 
open OUT, ">/tmp/fasta$$";
my %seen_label;
while (<IN>) {
  chomp;
  if (/^>(.+)/) {
    my $l = $1;
    $l =~ s/\s+/_/g; # NO white space!
    $l =~ s/_$//;    # NO trailing white space!
    if ($seen_label{$l}++) {
      $l = "$l\_$seen_label{$l}";
    }
    $_ = ">$l";
  }
  print OUT "$_\n"; 
}
system "mv /tmp/fasta$$ $fasta";


# execute Muscle
system(EXECUTABLE." ".$arguments);

my ($left_pad, @names) = get_names("fasta.aln");

substitute_names($left_pad,TEMPFILE,FINALFILE,@names);

0;


# grabs list of full names from fasta file (assumes same order)
sub get_names {
    my $fafile = shift || die "no fasta file name!\n";
    my @names;
    open FAIN, "grep \\> $fafile |" or die $!;
    while (<FAIN>) {
	chomp;
	s/\>//;
	push @names, $_;
    }
    close FAIN;


    # get max seq length for padding;
    my ($longest) = map {length} sort {length $b <=> length $a} @names;
    $longest++;
    my $pad = sprintf "%-$longest\s", '';
    @names = map { sprintf "%-$longest\s", $_ } @names;
    return ($pad,@names);
}

sub substitute_names{
    my $pad     = shift;
    my $infile  = shift;
    my $outfile = shift;
    my @names = @_;

    print STDERR "$infile\n";
    print STDERR "PAD |$pad|\n";
    open PHIN,  "<$infile"  || die "Cannot open phylip file $infile: $!\n";
    open PHOUT, ">$outfile" || die "Cannot open phylip file $outfile: $!\n";

    while (<PHIN>) {
	chomp;
	if (/^\s*(\d+)\s+(\d+)\s*$/) {
	    my $ntax   = $1;
	    my $nchars = $2;
	    die "names and number of taxa ($ntax) mismatch!\n" if $ntax != @names;
	    print PHOUT " $ntax $nchars\n";
	}
	elsif (/^(\S+)\s+/ && @names) {
	    my $old_name = $1;
	    my $new_name = shift @names;
	    s/^$old_name/$new_name/;
	    print STDERR "replaced name $old_name with $new_name\n";
	    print PHOUT "$_\n";
	}
	elsif (/^\S+/) {
	    print PHOUT "$pad$_\n";
	}
	else {
	    print PHOUT "$_\n";
	}
    }

    close PHIN;
    unlink $infile;
    close POUT;
    return 1;
}

