#!/usr/bin/perl
use strict;
use warnings;

open (my $swapfh, "-|", "cat /proc/swaps") or die "Can't open the swaps: $!";
my ($capacity, $usage);
while (my $line=<$swapfh>) {
	my ($device, $type, $size, $used, $priority) = split " ", $line;
	if ( $device eq "Filename" ) {
		print "Device\t\tPri\tSize\tUsed\t(%)\n";
	}
	else {
		print "$device\t$priority";
		print "\t" . int(100*$size/(1024*1024))/100 . "G";
		print "\t" . int(100*$used/(1024*1024))/100 . "G";
		print "\t" . int(100*$used/$size) . "%\n";
		$capacity += $size;
		$usage    += $used;
	}
}
print "All Devs\t-";
print "\t" . int(100*$capacity/(1024*1024))/100 . "G" ;
print "\t" . int(100*$usage/(1024*1024))/100 . "G";
print "\t" . int(100*$usage/$capacity) . "%\n";
close $swapfh;
