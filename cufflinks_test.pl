#!/usr/bin/perl -w
use strict;
use File::Copy qw/move copy/;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;

use constant CUFFLINKS  => ('1.3.0' => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/',
			    '2.0.2' => '/usr/local2/cufflinks-2.0.2.Linux_x86_64/',
			    '2.1.1' => '/usr/local2/cufflinks-2.1.1.Linux_x86_64/',
			    '2.2.0' => '/usr/local2/cufflinks-2.2.0.Linux_x86_64/');

report_input_stack();

# Define worflow options
my (@query_file, $query_dir, $annotation, $user_annotation, $version, $mask_file, $soft, $bias_fasta, $user_fasta);
$soft = 1;
$version = '2.0.2';

GetOptions( "infile=s"    => \@query_file,
	    "G=s"         => \$annotation,
            "M=s"         => \$user_annotation,
	    "mask-file=s" => \$mask_file,
	    "version=s"   => \$version,
	    "fasta=s"     => \$bias_fasta,
	    "user_fasta=s"=> \$user_fasta,
	    );

# more with this later, when they fix BOOLEANs
my $hard = 1 unless $soft;

my (@queries,$success);

if (@query_file) {
    push @queries, @query_file;
}

@queries > 0 || die "I could not find any SAM/BAM input files.\n";


# Allow over-ride of system-level database path with user
# May not need to do this going forward...
if (defined($user_annotation)) {
    $annotation = $user_annotation;
    `dos2unix $user_annotation`;
}

# Grab any flags or options we don't recognize and pass them as plain text
# Need to filter out options that are handled by the GetOptions call
my @args_to_reject = qw(-xxxx);
my $CUFFLINKS_ARGS = join(" ", @ARGV);
foreach my $a (@args_to_reject) {
    if ($CUFFLINKS_ARGS =~ /$a/) {
	report("Most arguments are legal for use with this script, but $a is not. Please omit it and submit again");
	exit 1;
    }
}

my %app = CUFFLINKS;
my $clpath = $app{$version} or die "Cufflinks version $version is not supported."; 
chomp($ENV{PATH} = `echo \$PATH`);
$ENV{PATH} = join(':',$ENV{PATH},$clpath);

my $cufflinks = $clpath . "cufflinks -o cufflinks_out";
my $g = $hard ? '-G' : "-g"; # use GTF as a guideline (soft) or only consider annotated transcripts (hard)
my $cmd = $annotation ? "$cufflinks $CUFFLINKS_ARGS $g $annotation " : "$cufflinks $CUFFLINKS_ARGS";


if ($mask_file) {
    `dos2unix $mask_file`;
    $cmd .= "-M $mask_file ";
}

if ($user_fasta) {
    `dos2unix $user_fasta`;
    $bias_fasta = $user_fasta;
}

if ($bias_fasta) {
    $cmd .= " -b $bias_fasta";
}

my $gtf_out = 'gtf';
for my $query_file (@queries) {    
    my $basename = $query_file;
    $basename =~ s/^\S+\/|\.\S+$//g;

    my $cuffcommand = $cmd . " $query_file";
    report("Executing: $cuffcommand");

    system("$cuffcommand");
    $success++ if -e "cufflinks_out/transcripts.gtf" && ! -z "cufflinks_out/transcripts.gtf";
    system("mv cufflinks_out $basename\_out");

    mkdir $gtf_out unless -d $gtf_out;
    system("cp $basename\_out/transcripts.gtf $gtf_out/$basename\_transcripts.gtf");
}

system "rm -f *.fai";

die "Something did not work, not transcripts.gtf file!" unless $success;

sub report {
    print STDERR "$_[0]\n";
}

sub report_input_stack {
    my @stack = @ARGV;
    my %arg;

    while (@stack) {
        my $k = shift @stack;
        my $v = shift @stack;
        if ($v =~ /^-/) {
            unshift @stack, $v;
            $v = 'TRUE';
        }
        push @{$arg{$k}}, $v;
    }

    report("Input parameters:");
    for (sort keys %arg) {
        report(sprintf("%-25s",$_) . join(',',@{$arg{$_}}));
    }
}

