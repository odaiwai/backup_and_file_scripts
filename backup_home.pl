#!/usr/bin/perl
use strict;
use warnings;

# script to copy from /home to /backup/home
my $verbose = 1;
my $cp_options = "au";
$cp_options .= "v" if $verbose;

my @dirs = `ls -tr /home`;
foreach my $dir (@dirs) {
	chomp $dir;
	print "copying $dir";
	if ($dir eq "BACKUP") {
		print "$dir: Not this one\n";
	} else {
		print "\n";
		my $result = `time rsync -aHAX --progress /home/$dir /backup/home/`;
		print "$result\n";
	}
}
