#!/usr/bin/perl

use strict;
use warnings;
my $for_real = 1;
#
# check the dmesg log for BTRFS errors after a scrub and delete the file
# should do a:
#	btrfs filesystem sync /home 
# after

# other way to root out csum issues:
# https://www.reddit.com/r/btrfs/comments/hcllay/how_to_cleanup_after_btrfs_scrub_checksum_errors/
# cd ~/; find . -execdir cat {} + > /dev/null
# this tries to cat each file in the filesystem to /dev/null
# it will trigger a csum error in dmesg if there's a problem
# 
# better regexp:
#           `dmesg | grep path: | sed -E 's/^.*\(path: (.*)\)$/\1/;' | sort |uniq > damaged_files.txt`;
my %top_levels;
my %files;
print "Reading dmesg...";
my @lines = `dmesg -T | grep BTRFS`;
for my $line (@lines) {
	chomp $line;
	if ( $line =~ /\(path: (.*)\)/ )  {
		my $file = "/home/$1";
		$files{$file}++;
	}
if  ( $line =~ /corrupt ([0-9]+)/ ) {
		my $inode = $1;
		my $result = `sudo btrfs inspect-internal inode-resolve $inode /home 2>&1`;
		if ( $? == 0 ) {
			chomp $result;
			print "INODE: $inode -> $result\n";
			$files{$result}++;
		}
	}
}
print "\n";

my @files = keys(%files); #`cat damaged_files.txt`;
# algorithm:
for my $file (@files) {
	chomp $file;
	print "FILE: $file ($files{$file})... ";
	my @parts = split "/", $file;
	my $top_level = "/$parts[1]/$parts[2]/$parts[3]/$parts[4]";
	#print "@parts, $top_level\n";
	$top_levels{$top_level}++;
	if ( -e $file ) {
		print "exists.\n";
		my $cmd = "sudo rm -rfv \"$file\"";
		print "$cmd";
		if ($for_real) {
			my $results = `time $cmd`;
			print "\t$results\n";
		}
	} else {
		print "not there!\n";
	}	
}
print "Syncing /home ... ";
my $results = `sudo btrfs filesystem sync /home`;
print "$results\n";

# print out the top levels to be restored.
my @top_levels = keys(%top_levels);
for my $top_level (@top_levels) {
		print "$top_level ($top_levels{$top_level})\n";
}
