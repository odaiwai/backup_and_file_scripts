#!/usr/bin/perl

use strict;
use warnings;

# better regexp:
#           `dmesg | grep path: | sed -E 's/^.*\(path: (.*)\)$/\1/;' | sort |uniq > damaged_files.txt`;
my @files = `cat damaged_files.txt`;
# provides a list that will need to be escaped for shell purposes (contains spaces)
# algorithm:
for my $file (@files) {
	chomp $file;
	my $filepath = "/home/$file";
	print "FILE: $filepath ... ";
	if ( -e $filepath ) {
		print "exists.\n";
		my $cmd = "rm -v \"$filepath\"";
		print "$cmd";
		my $results = `time $cmd`;
		print "\t$results\n";
	} else {
		print "not there!\n";
	}	
}
