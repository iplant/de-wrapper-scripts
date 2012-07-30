#!/usr/bin/perl -w
use strict;

# This script will recursively unpack compressed archives based on 
# de facto naming conventions
my $num = @ARGV;
for (@ARGV) {
    my $file = $_;
    my $type = /\.tar\.gz$|\.tgz$/     ? 'tgz' 
             : /\.tar$/                ? 'tar' 
             : /\.tar\.bz2?$|\.tbz2?$/ ? 'tbz' 
             : /\.bz2?$/               ? 'bz2'
             : /\.gz?$/                ? 'gz'
	     : /\.zip$/                ? 'zip'
	     :                        'unknown';

    #$type ||= 'unknown';
    #warn "FILE: $_; TYPE: $type\n";


    if ($type eq 'unknown') {
	usage($file);
    }
    else {
	print STDERR  "Decompressing file $_ of type $type\n";
    }

    if ($type eq 'tgz') {
	system "tar xzf $_";
    }
    elsif ($type eq 'tar') {
	system "tar xf $_";
    }
    elsif ($type eq 'tbz') {
	system "tar xjf $_";
    }
    elsif ($type eq 'bz') {
	system "bunzip2 $_";
    }
    elsif ($type eq 'gz') {
	system "gunzip $_";
    }
    elsif ($type eq 'zip') {
	system "unzip $_";
    }
}

usage('no input') unless $num;
print "Processed $num files\n";
exit 0;

sub usage {
    my $file = shift;
  print STDERR <<END;

Error: unknown file type: $file

Usage:
  decompress.pl file1 file2 etc
  Where files are tarballs/bombs (*.tar.gz or *.tgz or *.tar.bz2 or *.tbz2 or *.tar)
  or gzipped (*.gz) or bzipped (*.bz2) or zipped (*.zip)

END
;
  exit 1;
}


