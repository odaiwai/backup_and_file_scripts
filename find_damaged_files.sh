#!/usr/bin/perl

use strict;
use warnings;
my $for_real = 0;
#
# (c) dave o'brien 20210420
#
# check the dmesg log for BTRFS errors after a scrub and delete the file
# should do a:
#	btrfs filesystem sync /home 
# after deleting files before scrubbing again.

# other way to root out csum issues:
# https://www.reddit.com/r/btrfs/comments/hcllay/how_to_cleanup_after_btrfs_scrub_checksum_errors/
#
# cd ~/; find -type f .exec {} + -exec md5sum {} + 
#
# # this tries to read each file in the filesystem
# it will trigger a csum error in dmesg if there's a problem
# It will take a long time!
#
# When scrub runs with no errors, the restore_home.pl utility can restore the deleted files from the backup.  Very manual process so adjust it to suit.
#
my %top_levels;
my %files;
my %results;
print "Reading dmesg...";
my @lines = `dmesg -T | grep BTRFS`;
for my $line (@lines) {
	chomp $line;
	if ( $line =~ /\(path: (.*)\)/ )  {
		my $file = "/home/$1";
		$files{$file}++;
	}
	if  ( $line =~ /ino ([0-9]+) off/ ) {
		my $inode = $1;
		my $result = `sudo btrfs inspect-internal inode-resolve $inode /home 2>&1`;
		if ( $? == 0 ) {
			chomp $result;
			print "INODE: $inode -> $result\n";
			$files{$result}++;
		}
	}
#	if  ( $line =~ /logical ([0-9]+) on/ ) {
#		my $logical = $1;
#		my $result = `sudo btrfs inspect-internal logical-resolve $logical /home 2>&1`;
#		if ( $? == 0 ) {
#			chomp $result;
#			print "LOGICAL: $logical -> $result\n";
#			$files{$result}++;
#		}
#	}
if  ( $line =~ /inode ([0-9]+), offset/ ) {
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
my $deleted = 0;
# algorithm:
for my $file (@files) {
	chomp $file;
	my @parts = split "/", $file;
	my $top_level = "/$parts[1]/$parts[2]/$parts[3]/$parts[4]";
	#print "@parts, $top_level\n";
	$top_levels{$top_level}++;
	if ( -e $file ) {
		print "FILE: $file ($files{$file})... exists.\n";
		my $cmd = "sudo rm -rfv \"$file\"";
		print "$cmd";
		if ($for_real) {
			my $results = `time $cmd`;
			print "\t$results\n";
			$deleted++;
		}
	} else {
		print "$file not there!\n";
	}	
}
print "Deleted $deleted files. Syncing /home ... ";
my $results = `sudo btrfs filesystem sync /home`;
print "$results\n";

# print out the top levels to be restored.
my @top_levels = keys(%top_levels);
for my $top_level (@top_levels) {
		print "$top_level ($top_levels{$top_level})\n";
}

