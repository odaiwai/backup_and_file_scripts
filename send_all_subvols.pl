#!/usr/bin/perl 
use strict;
use warnings;

# In the normal mode of operation, we're copying subvols from /home to /backup
my $normal = 1;

if ( $normal ) {
	# Normal mode of operation: copy from /home to /backup
	my $source = "/home";
	my $dest = "/backup";
} else {
	my $source = "/backup";
	my $dest = "/home";
}

my @source_subvols   = `btrfs subvol list $source | cut -d' ' -f9`;
my @dest_subvols = `btrfs subvol list $dest | cut -d' ' -f9`;

my $previous_subvol = shift @source_subvols;
chomp $previous_subvol;

for my $this_subvol (@source_subvols) {
	chomp $this_subvol;
	# Check if already there, if so do nothing
	my $already_there = 0;
	for my $dest (@dest_subvols) {
		chomp $dest;
		if ( $this_subvol eq $dest ) {
			# Subvol is already on the dest - ignore
			$already_there++ ;
		}
	}
	if ( $already_there > 0 ) {
		print "$dest/$this_subvol - $already_there\n";
	} else {
		my $cmd = "btrfs send -v -p $source/$previous_subvol $source/$this_subvol | btrfs receive $dest"; 
		print "$cmd\nWaiting...";
		sleep 10;
		print "\n";
		my $result = `time $cmd`; 
		print "$result \n";
	}
	$previous_subvol = $this_subvol;
}

