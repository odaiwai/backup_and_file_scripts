#!/usr/bin/perl
use strict;
use warnings;
# Check if there are running scrubs on any pool and enable quotas where the scrub returns finished

my @pools = `mount| grep btrfs | cut -d' ' -f3`;
my %scrub_statuses;
for my $pool (@pools) {
	chomp $pool;
	$scrub_statuses{$pool} = 0;
}
my $num_pools = scalar(@pools);
my $all_scrubs_finished = 0;

# Main Loop
while ( !$all_scrubs_finished ) {
	my $all_scrub_status = 0;
	for my $pool (@pools) {
		chomp $pool;
		# Check if a scrub is running
		my $scrub_status = `btrfs scrub status $pool | grep finished | wc -l`;
		chomp $scrub_status;
		$all_scrub_status += $scrub_status;
		print "$pool has status $scrub_status\n";
		if ( $scrub_status == $scrub_statuses{$pool} ) {
			print "\tNo Change.\n";
		} else {
			$scrub_statuses{$pool} = $scrub_status;
			print "\tScrub status changed on $pool, enabling quotas...";
			my $result = `btrfs quota enable $pool`;
			print "\n";
		}
	}
	if ( $all_scrub_status == $num_pools) {
		$all_scrubs_finished = 1;
	} else {
		# take a nap, and check again...
		sleep 60;
	}
}
