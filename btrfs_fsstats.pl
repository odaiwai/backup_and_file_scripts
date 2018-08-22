#!/usr/bin/perl
use strict;
use warnings;

# Script to calculate the usage rates on the btrfs filesystems
# 20180718 Dave O'Brien
# Data, RAID0: total=5823975653376, used=5811974639616
# System, RAID1: total=67108864, used=344064
# Metadata, RAID1: total=11811160064, used=10064805888
# GlobalReserve, single: total=536870912, used=0

my @pools = `mount | grep btrfs | cut -d" " -f3`;
foreach my $pool (@pools) {
    chomp $pool;
    print "Pool: $pool\n";
    my @results = `btrfs fi df -b $pool`;
    foreach my $line (@results) {
        chomp $line;
        if ( $line
            =~ /(Data|System|Metadata), (RAID[0-9]|single): total=([0-9]+), used=([0-9]+)/
            )
        {
            my $type   = $1;
            my $format = $2;
            my $total  = $3;
            my $used   = $4;
            my $pct    = ( $used / $total ) * 100;
            print "$type, $format, $total, $used, "
                . sprintf( "%0.2f", $pct ) . "%\n";
        }
    }
}
