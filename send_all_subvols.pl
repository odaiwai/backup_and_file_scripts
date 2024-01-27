#!/usr/bin/perl 
use strict;
use warnings;

# In the normal mode of operation, we're copying subvols from /home to /backup
my $normal = 1;
my $source = "/home";
my $dest = "/backup";
my $sleep = 10;

if ( !$normal ) {
	my $source = "/backup";
	my $dest = "/home";
}

# Get the list of subvols
my @source_subvols   = `btrfs subvol list $source | cut -d' ' -f9`;
my @dest_subvols = `btrfs subvol list $dest | cut -d' ' -f9`;

# This works when there are common subvols.
# When there aren't it is required to send one subvol manually with:
# btrfs send $source/%subvol | btrfs receive $dest
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
		my $cmd = "btrfs send -v --proto 0 -p $source/$previous_subvol $source/$this_subvol | btrfs receive $dest"; 
		print "\n";
		my $result = `time $cmd`; 
		print "$result \n";
		print "$cmd\nWaiting $sleep seconds (ctrl-C here will stop safely)...";
		sleep ($sleep);
        print "Going round again...\n";
	}
	$previous_subvol = $this_subvol;
}

