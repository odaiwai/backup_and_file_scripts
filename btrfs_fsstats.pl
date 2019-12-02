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
my %pool_size;
my %pool_mounts;
my %pool_used;
my %pool_type_size;
my %pool_type_used;
my %pool_type_bal;

foreach my $pool (@pools) {
    chomp $pool;
    print "Pool: $pool\n";
    my @results = `df -B1 $pool; btrfs fi df -b $pool`;
    foreach my $line (@results) {
        chomp $line;
		if ( $line =~ /^([a-z0-9\/]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+\%) (.*)$/ ){
			my ($device, $total, $used, $avail, $used_pct, $mount) = ($1, $2, $3, $4, $5, $6);
			$pool_size{$pool} = $total;
			$pool_used{$pool} = $used;
			$pool_mounts{$pool} = $device;
			#print "$device: ($mount) $total/$used = $used_pct\n"; 
		}
        if ( $line =~ /(Data|System|Metadata), (RAID[0-9]|single): total=([0-9]+), used=([0-9]+)/ ) {
	            my $type   = $1;
	            my $format = $2;
	            my $total  = $3;
	            my $used   = $4;
	            my $pct    = ( $used / $total ) * 100;
				#print "$type, $format, $total, $used, " . sprintf( "%0.2f", $pct ) . "%\n";
				$pool_type_size{"$pool\_$type"} = $total;
				$pool_type_used{"$pool\_$type"} = $used;
				$pool_type_bal{"$pool\_$type"} = sprintf( "%0.2f", $pct) . "%";
        }
    }
	my $total_used = $pool_type_used{$pool."_Data"} + $pool_type_used{$pool."_Metadata"} + $pool_type_used{$pool."_System"};
	my $pool_type_bal = join "/", ($pool_type_bal{$pool.'_Data'}, $pool_type_bal{$pool.'_Metadata'}, $pool_type_bal{$pool.'_System'}); 
	my $pool_Data_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_Data"} / $pool_size{$pool} )) . "%";
	my $pool_Meta_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_Metadata"} / $pool_size{$pool} )) . "%";
	my $pool_Syst_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_System"} / $pool_size{$pool} )) . "%";
	print "$pool ($pool_mounts{$pool}) $total_used Data/Meta/Sys: ($pool_Data_pct/$pool_Meta_pct/$pool_Syst_pct) Balanced:($pool_type_bal)\n"; 
}

