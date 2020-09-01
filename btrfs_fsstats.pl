#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

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

# Get the list of all devices in each pool
my ($pool_devices_ref, $all_pool_devs) = devices_in_pools(@pools);
my %pool_devices = %$pool_devices_ref;	# $pool_devices{$pool}{N} = device N in pool $pool
#print Dumper(\%pool_devices);
#print Dumper($all_pool_devs);

#get the temperates for each device (includes non pool devices)
my $drive_temps_ref = drive_temps($all_pool_devs);
my %drive_temps = %$drive_temps_ref;
#print Dumper(\%drive_temps);


foreach my $pool (@pools) {
    chomp $pool;
	#print "Pool: $pool\n";
	
	# Make the string of temperatures
	my @pool_temps;
	for my $dev (split(' ', $pool_devices{$pool})) {
		push @pool_temps, $drive_temps{$dev};

	}
	#print Dumper(\@pool_temps);
	my $pool_temps = join('/', @pool_temps);
	#print Dumper($pool_temps);
	
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
        if ( $line =~ /(Data|System|Metadata), (RAID[0-9]|single|DUP): total=([0-9]+), used=([0-9]+)/ ) {
	            my $type   = $1;
	            my $format = $2;
	            my $total  = $3;
	            my $used   = $4;
	            my $pct    = ( $used / $total ) * 100;
				#print "$type, $format, $total, $used, " . sprintf( "%0.2f", $pct ) . "%\n";
				$pool_type_size{"$pool\_$type"} = $total;
				$pool_type_used{"$pool\_$type"} = $used;
				$pool_type_bal{"$pool\_$type"} = sprintf( "%0.1f", $pct) . "%";
        }
    }
	#print Dumper(%pool_type_used);
	my $total_used = $pool_type_used{$pool."_Data"} + $pool_type_used{$pool."_Metadata"} + $pool_type_used{$pool."_System"};
	#print Dumper(%pool_type_bal);
	my $pool_type_bal = join "/", ($pool_type_bal{$pool.'_Data'}, $pool_type_bal{$pool.'_Metadata'}, $pool_type_bal{$pool.'_System'}); 
	my $pool_Data_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_Data"} / $pool_size{$pool} )) . "%";
	my $pool_Meta_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_Metadata"} / $pool_size{$pool} )) . "%";
	my $pool_Syst_pct = sprintf ("%0.1f", ( 100 * $pool_type_size{$pool."_System"} / $pool_size{$pool} )) . "%";
	my $pretty_data = pretty_bytes($pool_type_size{$pool."_Data"});
	my $pretty_meta = pretty_bytes($pool_type_size{$pool."_Metadata"});
	my $pretty_syst = pretty_bytes($pool_type_size{$pool."_System"});
	my $pretty_total = pretty_bytes($total_used);
	print "$pool\t($pool_mounts{$pool}) $pretty_total Data/Meta/Sys: ($pretty_data/$pretty_meta/$pretty_syst) ($pool_Data_pct/$pool_Meta_pct/$pool_Syst_pct) Balanced:($pool_type_bal), $pool_temps\n"; 
}

sub pretty_bytes {
	# given a number of b, return a nice looking number like 1.21 GB
	# optional: use powers of ten instead?
	my $size = shift;
	my $scale = shift;
	my $base = 1024;
	my @suffixes=("B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"); # Bytes
	my @longsuffixes=("Bytes", "Kibibytes", "Mebibytes", "Gibibytes", "Tebibytes", "Pebibytes", "Exbibytes", "Zebibytes", "Yobibytes"); # Bytes
	if (defined($scale) and $scale == 1) {
		# using powers of 10
		$base = 1000;
		@suffixes=("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"); # Bytes
		@longsuffixes=("Bytes", "Kilobytes", "Megabytes", "Gigabytes", "Terabytes", "Petabytes", "Exabytes", "Zettabytes", "Yottabytes"); # Bytes
	}
	$size *= $base ; # Usage reported in KB as default
	my $new_size;
	$size /= $base; # divide to get KiB/KB
	for ( my $power=0; $power<9; $power++) {
		my $divisor = ($base) ** $power;
		#print "1024 ^ $power = $divisor\n";
		if ( $size > $divisor ) { $new_size=sprintf ( "%.2f",($size / $divisor)) . "$suffixes[$power]" ; }
	}
	return $new_size;
}
sub devices_in_pools {
	# return the devices in a given pool
	my @pools = @_;
	my %pool_devices;	# location of devices
	my @all_pool_devs;	# All devices in pools
	for my $pool (@pools) {
		chomp $pool;
		my @pool_devs; # string with the pools in it
		my @lines = `btrfs filesystem show $pool`;
		for my $line (@lines) {
			chomp $line;
			if ( $line =~ /devid/) {
				$line =~ s/^\s+(devid.*)/$1/;
				my @components = split(' ', $line);
				my $pnum = $components[1];
				my $dev = $components[-1];
				push @all_pool_devs, $dev;
				push @pool_devs, $dev;
			}
		}
		$pool_devices{$pool} = join(' ', @pool_devs);
	}
	my $all_pool_devs = join(' ', @all_pool_devs);
	return (\%pool_devices, $all_pool_devs);
}
sub drive_temps {
	# Return the temperatures of the drives in the string provided
	my $devs = shift;
	my @temps = `hddtemp $devs`;
	my %drive_temps;
	for my $temp (@temps) {
		chomp $temp;
		my ($dev, $model, $temp) = split(': ', $temp);
		$drive_temps{$dev} = $temp;
	}
	return \%drive_temps;
}
