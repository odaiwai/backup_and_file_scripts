#!/usr/bin/perl
use strict;
use warnings;

# Script to find all versions of a file in the current snapshots
# 20181212 Dave O'Brien

my $verbose = 1;
my $filesystem = "/home";
my @snapshots = list_all_snapshots($filesystem);
# Algorithm:
# For each file on stdin, show the distinct versions of it in the snapshots.
#

foreach my $file (@ARGV) {
	chomp $file;
	print "$file\n";

	my ($perms, $size, $date, $time, $filename) = fileinfo($file);
	print "$perms, $size, $date, $time: $filename\n" if $verbose;
	
	my $fullpath = `realpath --relative-to $filesystem $file`;
	chomp $fullpath;

	foreach my $snapshot (@snapshots) {
		my $snappath = "$filesystem/$snapshot/$fullpath";
		if ( -f $snappath ) {
			my ($s_perms, $s_size, $s_date, $s_time, $s_filename) = fileinfo($snappath);
			if (($date ne $s_date) || ($time ne $s_time) || ($size != $s_size) ) {
				print "\t$s_size, $s_date, $s_time: $s_filename\n" if $verbose;
			}
		}
	}
}

sub fileinfo {
	# Get the relevant data on a file
	my $file = shift;
	
	my $data = `ls -l --time-style=long-iso $file`;
	my @data = split " ", $data;
	my $perms  = shift @data;
	my $copies = shift @data;
	my $owner  = shift @data;
	my $group  = shift @data;
	my $size   = shift @data;
	my $date   = shift @data;
	my $time   = shift @data;
	my $filename = join " ", @data;
	return ($perms, $size, $date, $time, $filename);
}

sub list_all_snapshots {
	# find all the snapshots in the current filesystem
	my $filesystem = shift;
	my @snapshots;
	
	my @subvolumes = `sudo btrfs subvolume list $filesystem`;
	foreach my $subvolume (@subvolumes) {
		if ( $subvolume =~ /^ID ([0-9]+) gen ([0-9]+) top level ([0-9]+) path (.*)$/ ) {
			my ($id, $gen, $root, $snapshot) = ($1, $2, $3, $4);
			#print "\t$id/$gen/$root/$snapshot\n" if $verbose;
			push @snapshots, $snapshot;
		}
	}
	#
	return @snapshots;
}

