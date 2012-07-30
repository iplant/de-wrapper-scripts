#!/usr/bin/perl

use warnings;
use strict;

while (<>) {
    chomp;
    my @parts = split /\t/;
    print "@","$parts[0]:$parts[2]:$parts[3]:$parts[4]:$parts[5]#$parts[6]/$parts[7]\n";
    print "$parts[8]\n";
    print "+\n";
    print "$parts[9]\n";
}
