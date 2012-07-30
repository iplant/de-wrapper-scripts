#!/usr/bin/perl -w
use strict;
use lib '/usr/local2/sheldon/lib';
use DE_util;
use Digest::MD5 'md5_hex';

use constant BINARY => '/usr/local2/sheldon/bin/contrast';

# Command line arguments for contrast (not exhaustive)
# i non PHYLIP option for input file (required)
# t non PHYLIP option for input tree (required)
# R BOOLEAN print out regressions (default true)
# C BOOLEAN print out contrasts (default false)
# M number of trees (if > 1)

# Letters followed by a colon expect an argument
# Letters without a colon are BOOLEAN
my $option_string = 'RCt:i:M:';
my $opt = get_options($option_string,{});
my %opt = %$opt;

# sanity check DNAML specific arguments
check_options(%opt);
cleanup();

# standardize the names, save them to infile
my $names = munge_infile($opt{i},'infile');
my %rnames = reverse %$names;
my $tree = `cat $opt{t}`;
for my $k (keys %rnames) {
    $tree =~ s/\b$k\b/$rnames{$k}/gm;
}
my $treeout = IO::File->new('>intree');
print $treeout $tree;
$treeout->close;


# build up command file
my $stdin = ''; 
$stdin .= "R\n"          unless $opt{R};
$stdin .= "C\n"          if $opt{C};
$stdin .= "M\n$opt{M}\n" if $opt{M};      
$stdin .= "Y\n\n";


# run the job (cross you fingers!)
run($stdin,BINARY);


# clean up
my $infile = $opt{i};
$infile =~ s/\.[^.]+$//;
deobfuscate_names('outfile',"output.txt",$names);
cleanup();

sub check_options {
    my %opt = @_;
    $opt{t} or die "Must provide a tree file -t treefile";
    delete $opt{M} if $opt{M} && $opt{M} == 1;
}

sub munge_infile {
    my $in  =  shift or die "Provide an input file name";
    my $out =  shift or die "Provide an output file name";

    my %name = ();

    my $fhi = IO::File->new($in);
    die "could not open file handle for $in" unless $fhi;
    my $fho = IO::File->new("> $out");
    die "Could not open file handle for $out" unless $fho;

    while (my $l = <$fhi>) {
	chomp $l;
        if ($l =~ /^(\S.*\s*)$/) {
            my @x = split /\s+/, $l;

            # Replace names with an md5_hex key
            my $real_name = $x[0];
	    my $name_key  = md5_hex($$.$real_name);
	    $name{$name_key} = $real_name;
	    $l =~ s/$real_name/$name_key/;
            $l =~ s/\s+/  / if $l =~ /^\S/;     
	    print $fho $l, "\n";
        }
        else {
            print $fho $l, "\n";
	}
    }

    $fhi->close;
    $fho->close;

    return \%name;
}
