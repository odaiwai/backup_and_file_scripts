#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: dedupe_a_file.pl
#        USAGE: ./dedupe_a_file.pl  
#  DESCRIPTION: Dedup a file across all the snapshots 
#       AUTHOR: Dave OBrien (odaiwai), odaiwai@diaspoir.net
#      CREATED: 12/02/2019 07:50:49 PM
#===============================================================================
use strict;
use warnings;
use utf8;

# Algorithm:
#	Set all of the snapshots to RW
#	Pass the file and all snapshots to duperemove
#	Wait for that to finish
#	Set all of the snapshots to RO again
#

my @files = @ARGV;
my $filesystem = "/home";
my $alt_filesystem = "/backup";
my @snapshots = get_list_of_snapshots($filesystem);
my $verbose = 1;
my $for_real = 1;

#print @snapshots . "\n";
# Set snapshots to RW
for my $snapshot (@snapshots) {
	my $result = set_property($filesystem, "ro false", $snapshot);
}

# find all instances of the file
# delete the snapshots only - not the main file
for my $file (@files) {	
	my $path = `realpath $file | sed 's/\\$filesystem//g;'`;
	chomp $path;
	print "Main File: $filesystem$path\n";
	my @file_versions;
	for my $snapshot (@snapshots) {
		chomp $snapshot;
		push @file_versions, "$filesystem/$snapshot$path";
		print "\t$filesystem/$snapshot$path\n" if $verbose;
	}
	my $allfiles = join " ", @file_versions;
	print "Delete $allfiles\n";
	for my $version (@file_versions) {
		my $cmd = "rm -rf $version";
		print "$cmd\n" if $verbose;
		my $result = do_cmd($cmd);
		print "$result\n" if $verbose;
	}
}

# Set snapshots to RO
for my $snapshot (@snapshots) {
	my $result = set_property($filesystem, "ro true", $snapshot);
}

### Subs
sub get_list_of_snapshots {
	my $filesystem = shift;
	my @snapshots;
	open (my $fh, "-|", "btrfs subvolume list $filesystem | cut -d\" \" -f 9");
	while ( my $snapshot = <$fh> ) {
		chomp $snapshot;
		push @snapshots, $snapshot;
	}
	close $fh;
	return @snapshots;
}

sub set_property {
	my $filesystem = shift;
	my $parameters = shift;
	my $snapshot = shift;
	my $cmd = `btrfs property set $filesystem/$snapshot $parameters`;
	my $result = do_cmd($cmd);
	return $result;
}

sub do_cmd {
	my $cmd = shift;
	#print "$cmd\n" if $verbose;
	my $result = "NULL"; 
	$result = `$cmd` if $for_real;
	chomp $result;
	return $result;
}
