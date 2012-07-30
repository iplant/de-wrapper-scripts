#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;

use constant PATH   => '/usr/local3/bin/cufflinks-1.3.0.Linux_x86_64';
use constant BINARY => 'cuffdiff';

my $cannedReference      = '';
my $userReference        = '';
my (@sampleOne,@sampleTwo,@sampleThree,@sampleFour,@sampleFive,@sampleSix,@sampleSeven,@sampleEight,@sampleNine,@sampleTen);
my ($tophat_out,$cuffmerge_out,$nameOne,$nameTwo,$nameThree,$nameFour,$nameFive,$nameSix,$nameSeven,$nameEight,$nameNine,$nameTen,$version);

my $result = GetOptions (
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
                          'sampleTen:s'           => \@sampleTen,
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
			  'version=s'             => \$version
);

# Annotation sanity check
unless ($cannedReference || $userReference) {
    die "Reference or custom annotations must be supplied for CuffDiff\n";
}
# Custom trumps canned
if ($userReference) {
    $cannedReference = $userReference;
}

my $cmd = PATH . "/" . BINARY;


# get rid of empty labels (assumes in order)
my @labels = grep {$_} ($nameOne,$nameTwo,$nameThree,$nameFour,$nameFive,$nameSix,$nameSeven,$nameEight,$nameNine,$nameTen);
my $ARGS = join(' ', @ARGV);
$cmd .= " $ARGS ";
if (@labels) {
    $cmd .= ' -u  --labels '.join(',',@labels).' ';
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

print STDERR "Running $cmd\n";

system($cmd);

# Now plot a few graphs
my @pairs;
my %pair;
for my $i (@labels) {
    for my $j (@labels) {
	my $pair = join '.', sort ($i,$j);
	next if $pair{$pair}++ || $i eq $j;
	push @pairs, [$i,$j];
    }
}

my $r = <<END;
library(cummeRbund)
cuff <- readCufflinks()
png('../graphs/density_plot.png')
csDensity(genes(cuff))
dev.off()
END
;

for (@pairs) {
    my ($i,$j) = @$_;
    $r .= <<END;
png("../graphs/$i\_$j\_scatter_plot.png")
csScatter(genes(cuff),"$i","$j",smooth=T)
dev.off()
png("../graphs/$i\_$j\_volcano_plot.png")
csVolcano(genes(cuff),"$i","$j");
dev.off()
END
;

}

open RS, ">cuffdiff_out/basic_plots.R";
print RS $r;
close RS;

system "mkdir graphs";
chdir "cuffdiff_out";
system "perl -i -pe 's/(\\S)\\s+?\\#/$1\\-/' *.*";
system "R --vanilla < basic_plots.R";

exit 0;
