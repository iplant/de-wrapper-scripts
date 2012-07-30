#!/usr/bin/perl -w
use strict;
use File::Copy 'move';
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use constant CUFFLINKS  => '/usr/local2/cufflinks-1.3.0.Linux_x86_64/';

# Define worflow options
my $conf_file;

GetOptions("config_file=s" => \$conf_file);

my $success;
my ($conf,@queries) = config($conf_file);

my $CUFFLINKS_ARGS = join(" ", @ARGV);
my $app = CUFFLINKS . "cufflinks";
my $cmd = "$app $CUFFLINKS_ARGS -G $conf->{reference}->{gtf} ";

my $merge_file;
for my $query_file (@queries) {    
    my $basename = $query_file;
    $basename =~ s/^\S+\/|\.\S+$//g;
    $basename = "$conf->{output}->{cufflinks}/$basename";
    my $cuffcommand = $cmd . " -o $basename $query_file";
    $cuffcommand .= " $query_file/accepted_hits.bam";
    report("Executing: $cuffcommand");

    system $cuffcommand;

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

sub config {
    my $conf = shift;
    my @bam;
    my %conf;
    open CONF, $conf or die "Problem with config file $conf $!\n";
    while (<CONF>) {
        chomp;
	my ($class,$key,$val) = split;
        if ($class eq 'bam') {
            push @{$conf{$class}->{$key}}, $val;
            push @bam, $val;
        }
        else {
            $conf{$class}->{$key} = $val;
        }
    }
    return \%conf,@bam;
}
