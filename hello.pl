#!/usr/bin/perl -w
use strict;
use Getopt::Long;

my ($name, $age);
GetOptions( 'name=s' => \$name, 'age=i' => \$age );

my $usage = <<END;

Usage: ./hello.pl --name name --age age
       Where name is a string and age is an integer
END
    ;



$name || die $usage;
$age  || die $usage;

my $dog_years = $age * 7;

open OUT, ">README_ARF.txt";

print OUT <<END;

Hello $name!
You are $age years old! I hope you are not fibbing.
Did you know that is $dog_years in dog years?

END


close OUT;

exit 0;
