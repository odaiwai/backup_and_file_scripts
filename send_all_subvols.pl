#!/usr/bin/perl 
use strict;
use warnings;

my @home_subvols   = `btrfs subvol list /home | cut -d' ' -f9`;
my @backup_subvols = `btrfs subvol list /backup | cut -d' ' -f9`;

my $previous_subvol = shift @home_subvols;
chomp $previous_subvol;

for my $this_subvol (@home_subvols) {
	chomp $this_subvol;
	# Check if already there, if so do nothing
	my $already_there = 0;
	for my $backup (@backup_subvols) {
		chomp $backup;
		if ( $this_subvol eq $backup ) {
			# Subvol is already on the backup - ignore
			$already_there++ ;
		}
	}
	if ( $already_there > 0 ) {
		print "/backup/$this_subvol - $already_there\n";
	} else {
		my $cmd = "btrfs send -v -p /home/$previous_subvol /home/$this_subvol | btrfs receive /backup"; 
		print "$cmd\nWaiting...";
		sleep 10;
		print "\n";
		my $result = `time $cmd`; 
		print "$result \n";
	}
	$previous_subvol = $this_subvol;
}

