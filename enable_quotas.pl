#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: enable_quotas.pl
#
#        USAGE: ./enable_quotas.pl  
#
#       AUTHOR: Dave OBrien (odaiwai), odaiwai@diaspoir.net
# ORGANIZATION: OBrien consulting
#      VERSION: 1.0
#      CREATED: 07/05/2019 10:44:18 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Data::Dumper;

# constants
my $verbose = 0;

# get the pools 
my @pools = `mount | grep btrfs | cut -d" " -f3`;

foreach my $pool ( @pools ) {
	chomp $pool;
	# Check is the quotas are enabled
	my $no_quota = check_status( "btrfs qgroup show", "quotas not enabled", $pool);
	
	# check if a scrub is running
	my $no_scrub = check_status( "btrfs scrub status", "finished after", $pool);
	
	#if no quotas and no scrub, enable the quota
	if ( $no_quota and $no_scrub ) {
		my $command = "btrfs quota enable $pool";
		print "$command\n" if $verbose;
		my $result = `btrfs quota enable $pool`; 
		print "$result" if $verbose;
	}
}

sub check_status {
	my $command = shift;
	my $test = shift;
	my $pool = shift;
	
	my $status = 0;
	my @results = `$command $pool 2>&1`; 
	#print Dumper(@results);
	foreach my $line (@results) {
		chomp $line;
		#print "LINE:$line\n" if $verbose;
		if ( $line =~ /$test/ ) {
			$status = 1;
		}
	}

	print "CMD: $command: Test: $test Pool: $pool RESULT: $status\n" if $verbose;
	return $status;
}
