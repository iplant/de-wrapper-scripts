#!/usr/bin/perl -w
use strict;
use File::Copy 'move';
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

use constant CUFFLINKS  => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/';

# Define worflow options
my ($query_file, $query_dir, $annotation, $user_annotation, $version);

GetOptions( "infile=s"  => \$query_file,
	    "indir=s"   => \$query_dir,
	    "G=s"       => \$annotation,
            "M=s"       => \$user_annotation,
	    "version=s" => \$version
	    );

my (@queries,$success);

# check if we are in a workflow 

if (-d "tophat_out") {
    $query_dir = "tophat_out/bam";
    undef $query_file;
}

if ($query_dir) {
    while (<$query_dir/*am>) {
	push @queries, $_ unless -d $_;
    }
    # look for nested directories
    while (<$query_dir/*/*am>) {
        push @queries, $_;
    }
}
if ($query_file) {
    push @queries, $query_file;
}

@queries > 0 || die "I could not find any SAM/BAM input files.\n";


# Allow over-ride of system-level database path with user
# May not need to do this going forward...
if (defined($user_annotation)) {
    $annotation = $user_annotation;
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

my $app = CUFFLINKS . "cufflinks";
my $cmd = "$app $CUFFLINKS_ARGS -g $annotation ";


my $merge_file;
for my $query_file (@queries) {    
    my $basename = $query_file;
    $basename =~ s/^\S+\/|\.\S+$//g;

    my $cuffcommand = $cmd . $query_file;
    report("Executing: $cuffcommand");

    system("$cuffcommand");

    mkdir "cufflinks_out";
    $basename = "cufflinks_out/$basename";
    mkdir $basename;

    while (<*.gtf>) {
	move($_, $basename);
    }
    while (<*.fpkm_tracking>) {
        move($_, $basename);
    }
    $merge_file .= "$basename/transcripts.gtf\n";
    $success++ if -e "$basename/transcripts.gtf";
}

open MERGE, ">cufflinks_out/gtf_to_merge.txt";
print MERGE $merge_file;
close MERGE;

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}

