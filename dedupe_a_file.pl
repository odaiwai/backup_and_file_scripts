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
my @snapshots = get_list_of_snapshots($filesystem);
my $verbose = 1;
my $for_real = 1;

#print @snapshots . "\n";
# Set snapshots to RW
for my $snapshot (@snapshots) {
	my $result = set_property($filesystem, "ro false", $snapshot);
}

# find all instances of the file
# run duperemove on the file
for my $file (@files) {	
	my $path = `realpath $file | sed 's/\\$filesystem//g;'`;
	chomp $path;
	print "Main File: $filesystem$path\n";
	my @file_versions;
	push @file_versions, "$filesystem$path"; 
	for my $snapshot (@snapshots) {
		chomp $snapshot;
		push @file_versions, "$filesystem/$snapshot$path";
		print "\t$filesystem/$snapshot$path\n" if $verbose;
	}
	my $allfiles = join " ", @file_versions;
	print "Running duperemove... on $allfiles\n";
	open ( my $fh, "-", "duperemove -r -d $allfiles") or die "Can't open command! $!";
	while (my $line = <$fh>) {
		chomp $line;
		print "$line \n" if $verbose;
	}
	close $fh;
	print "$result\n" if $verbose;
}

# Set snapshots to RO
for my $snapshot (@snapshots) {
	my $result = set_property($filesystem, "ro true", $snapshot);
}


sub get_list_of_snapshots {
	my $filesystem = shift;
	my @snapshots;
	open (my $fh, "-|", "btrfs subvolume list $filesystem | cut -d\" \" -f 9");
	while ( my $snapshot = <$fh> ) {
		chomp $snapshot;
		push @snapshots, $snapshot;
	}
	close_$fh;
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
	my $result = `$cmd` if $for_real;
	return $result;
}
