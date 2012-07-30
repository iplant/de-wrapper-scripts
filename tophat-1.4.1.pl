#!/usr/bin/perl -w
use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

use constant TOPHATP    => ('1.4.1'  => '/usr/local2/tophat-1.4.1.Linux_x86_64/',
			    '2.0.0'  => '');
use constant BOWTIEP    => ('0.12.7' => '/usr/local2/bowtie-0.12.7/',
			    '2.0.0'  => '/usr/local2/bowtie2-2.0.0-beta6/');
use constant SAMTOOLSP  => '/usr/local2/samtools-0.1.18/';

my ($file_query, $folder_query, $database_path, $user_database_path, $annotation_path, 
$user_annotation_path, $file_names, $root_names, $null);

my $format  = 'SE';
my $version = '1.4.1';

GetOptions( "file_query=s"      => \$file_query,
	    "folder_query=s"    => \$folder_query,
	    "database=s"        => \$database_path,
	    "user_database=s"   => \$user_database_path,
            "annotation=s"      => \$annotation_path,
            "user_annotation=s" => \$user_annotation_path,
	    "file_names=s"      => \$file_names,
	    "root_names=s"      => \$root_names,
            "tophat_version=s"  => \$version,
	    "bowtie_version=s"  => \$null
	    );

if (!($user_database_path || $database_path)) {
    die "No reference genome was supplied\n";
}
if (!($file_query || $folder_query)) {
    die "No FASTQ files were supplied\n";
}

my %tophat = TOPHATP;
my %bowtie = BOWTIEP;

my $tophatp   = $tophat{$version};
my $btversion = $version eq '1.4.1' ? '0.12.7' : '2.0.0';
my $bowtiep   = $bowtie{$btversion};

chomp($ENV{PATH} = `echo \$PATH`);
$ENV{PATH} = join(':',$ENV{PATH},$tophatp,$bowtiep,SAMTOOLSP);

# Allow over-ride of system-level database path with user
if ($user_database_path) {
  $database_path = $user_database_path;
  unless (`grep \\> $database_path`) {
      die "Error: $database_path  the user supplied file is not a FASTA file";
  }
  my $name = basename($database_path, qw/.fa .fas .fasta .fna/);
  print STDERR "bowtie-indexing $name\n";
  system BOWTIEP . "bowtie-build $database_path $name";
  $database_path = $name;
}
if ($user_annotation_path) {
    $annotation_path = $user_annotation_path;
}

my $success = undef;

# is this a directory or a file
my @query_file;
if ($folder_query) {
    if (-d $folder_query) {
	while (<$folder_query/*>) {
	    push @query_file, $_;
	}
    }
}

if ($file_query) {
    push @query_file, $file_query;
}

if (!@query_file) {
    die "Error: no fastq file(s) specified\n";
}

my (@basenames,%sample);

if ($root_names) {
    my @names = split(',',$root_names);
    for my $name (@names) {
	next if grep {/^$name|\/$name/} @query_file;
        die "Root name $name does not match any query file in the list\n";
    }
}
elsif ($file_names) {
    my $idx;
    my @names = split (/\s+/,$file_names); 
    for my $sample (@names) {
	$idx++;
	my @files = split(',',$sample);
	for (@files) {
	    $sample{$_} = "sample$idx";
	}
    }
    for my $file (@query_file) {
	my $f = $file;
	$f =~ s!\S+/!!;
	next if $sample{$f};
	die "$file does not match any name in the list\n";
    }
}


my $nocount;
my $samples;
my @to_move = ('bam');
for my $query_file (@query_file) {
 #   system "rm -fr tophat_out";
    # Grab any flags or options we don't recognize and pass them as plain text
    # Need to filter out options that are handled by the GetOptions call
    my @args_to_reject = qw(-xxxx);
    my $TOPHAT_ARGS = join(" ", @ARGV);
    foreach my $a (@args_to_reject) {
	if ($TOPHAT_ARGS =~ /$a/) {
	    report("Most TopHat arguments are legal for use with this script, but $a is not. Please omit it and submit again");
	    exit 1;
	}
    }

    my $app  = $tophatp.'tophat';
    if ($annotation_path) {
	$TOPHAT_ARGS .= " -G $annotation_path";
    }
    my $align_command = "$app $TOPHAT_ARGS $database_path $query_file";
    
    chomp(my $basename = `basename $query_file`);
    $basename =~ s/\.\S+$//;
    push @to_move, $basename;

    report("Executing: $align_command\n");
    system $align_command;
    system "mv tophat_out $basename";
    $success++ if -e "$basename/accepted_hits.bam";
    my $bam = 'bam';
    mkdir($bam) unless -d $bam;

    my %matched;
    if ($root_names) {
	my @names = split(',',$root_names);
	for my $root (@names) {
	    if ($query_file =~ /^$root|\/$root/) {
		system "mkdir $bam/$root" unless -d "$bam/$root";
		system "cp $basename/accepted_hits.bam $bam/$root/$basename.bam";
		$samples .= join("\t", $root, "$bam/$root/$basename.bam")."\n";
		last;
	    }
 	}
    }
    elsif ($file_names) {
	my @samples = map {[split(',',$_)]} split(/\s+/,$file_names);
	my $idx;
	for (@samples) {
	    $idx++ unless $nocount;
	    next unless grep {/$query_file/} @$_;
	    system "mkdir $bam/sample$idx" unless -e "$bam/sample$idx";
	    system "cp $basename/accepted_hits.bam $bam/sample$idx/$basename.bam";
	    $samples.= join("\t", "sample$idx", "$bam/sample$idx/$basename.bam")."\n";
	    $nocount = undef;
	    last;
	}
    }
    else {
	system "cp $basename/accepted_hits.bam $bam/$basename.bam";
    }
}



mkdir 'tophat_out' unless -d 'tophat_out';
mkdir 'bam';
for (@to_move) {
    system "mv $_ tophat_out" or warn $!;
    system "ln -s $_/accepted_hits.bam bam/$_.bam";
}

system "rm -f *.ebwt 2>/dev/null";

$success ? exit 0 : exit 1;

sub report {
    print STDERR "$_[0]\n";
}

