#!/usr/bin/perl
use strict;
use warnings;

# Script to update the /etc/updatedb.conf file with all of the snapshots
# included.
# 20181229 Dave O'Brien
#

my $verbose = 1;
my $update_conf = "/etc/updatedb.conf";
my %settings;

# Read in the file
open ( my $fh, "<", $update_conf);
while (my $line = <$fh>) {
	chomp $line;
	print "$line\n" if $verbose;
	
	if ( $line =~ /^([A-Z_]+) = \"(.*)\"$/) {
		my $keyword = $1;
		my $values  = $2;
		print "\t$keyword = $values\n" if $verbose;
		
		# handle the final PRUNEPATHS
		if ( $keyword eq "PRUNEPATHS" ) {
			my @newpaths;
			my @paths = split " ", $values;
			foreach my $path (@paths) {
				if ( $path =~ /BACKUP/ ) {
					# ignore
				} else {
					push @newpaths, $path;
				}
			}
			
			push @newpaths, list_all_snapshots("/home");
			$values = join " ", @newpaths;
			print "\t$keyword = $values\n" if $verbose;
		}
		$settings{$keyword} = $values;
	}
}
close $fh;

# Write the file
open ( my $outfh, ">", $update_conf);
foreach my $keyword (keys %settings) {
	if (exists ($settings{$keyword})) {
		print "$keyword = \"$settings{$keyword}\"\n" if $verbose;
		print $outfh "$keyword = \"$settings{$keyword}\"\n";
	}
}
close $outfh;

sub list_all_snapshots {
	# find all the snapshots in the current filesystem
	my $filesystem = shift;
	my @snapshots;
	
	my @subvolumes = `sudo btrfs subvolume list $filesystem`;
	foreach my $subvolume (@subvolumes) {
		if ( $subvolume =~ /^ID ([0-9]+) gen ([0-9]+) top level ([0-9]+) path (.*)$/ ) {
			my ($id, $gen, $root, $snapshot) = ($1, $2, $3, $4);
			#print "\t$id/$gen/$root/$snapshot\n" if $verbose;
			push @snapshots, "$filesystem/$snapshot";
		}
	}
	#
	return @snapshots;
}