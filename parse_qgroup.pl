#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# Script to make a table of the subvolumes on the system and link them to their
# sizes
#
# Dave O'Brien 20161008

my $verbose = 1;
my $sudo = '';
my $maximum_size = 0;

my @filesystems = qw/home/;
for my $filesystem (@filesystems) {
	my @snapshots = snapshots("/$filesystem");
}

# Determine the filesystems
sub filesystems {
    my @filesystems;
    my $cmd = "$sudo btrfs fi show";
    open ( my $fh, "-|", $cmd) or die "Can't execute command: $cmd.";
    while (my $line = <$fh>) {
        chomp $line;
        if ( $line =~ /^Label: '(.*)'  uuid: ([a-f0-9-]+)$/){
            my $label = $1;
            my $uuid = $2;
            print "\t$label, $uuid\n" if $verbose;
        }
        if ( $line =~ /devid\s+([0-9]+) size ([0-9.]+)([A-Za-z]+) used ([0-9.]+)([A-Za-z]+) path ([a-z0-9\/]+)$/) {
            my $devid = $1;
            my $size = $2;
            my $size_units = $3;
            my $used = $4;
            my $used_units = $5;
            my $device = $6;
			#print "\t$devid: $device. $used $used_units/$size $size_units\n" if $verbose;
        }
    }
    close $fh;
    return @filesystems;
}
sub snapshots {
    # Parse the snapshots for a given filesystem
    my $filesystem = shift;
    my %snapshots;
	my $snapshot = Snapshot->new(5, 0, $filesystem, 0, 0);
    $snapshots{5} = $snapshot;
    my %parents;
	$parents{5}++;
    my $cmd = "$sudo btrfs subvolume list $filesystem";
    open ( my $fh, "-|", $cmd) or die "can't execute command: $cmd.";
    while (my $line = <$fh>) {
        if ( $line =~ /^ID ([0-9]+) gen ([0-9]+) top level ([0-9]+) path (.*)$/) {
            my ($id, $gen, $parent, $path) = ($1, $2, $3, $4);
			#print "$parent->$id: $filesystem/$path\n" if $verbose;
            $parents{$parent}++;
            my $snapshot = Snapshot->new($id, $parent, $path, 0, 0);
            $snapshots{$id} = $snapshot;
        }
    }
    close $fh;
    # get the qgroups to determine the size of each snapshop
    $cmd = "$sudo btrfs qgroup show --raw $filesystem";
    open ( $fh, "-|", $cmd) or die "can't execute command: $cmd.";
    while (my $line = <$fh>) {
        chomp $line;
        #print "|$line|\n" if $verbose;
        #if ($line =~ /^([0-9]+)[\/]([0-9]+)\s+([0-9.]+)([A-Za-z]+)\s+([0-9.]+)([A-Za-z]+)$/) {
        #my ($parent, $id, $app_size, $app_size_units, $excl_size, $excl_size_units) = ($1, $2, $3, $4, $5, $6);
        #print "$parent->$id: $excl_size $excl_size_units ($app_size $app_size_units)\n" if $verbose;
        if ($line =~ /^([0-9]+)[\/]([0-9]+)\s+([0-9.]+)\s+([0-9.]+)\s*$/) {
            my ($parent, $id, $app_size, $excl_size) = ($1, $2, $3, $4);
            #print "$parent->$id: $excl_size ($app_size)\n" if $verbose;
            if (exists($snapshots{$id})) {
                $snapshots{$id}->{excl_size} = $excl_size;
                $snapshots{$id}->{app_size} = $app_size;
            }
        }
    }
    close $fh;
    foreach my $id (sort keys %snapshots) {
            if (exists ($snapshots{$id})) {
                    #       print Dumper($snapshots{$id});
                print "$snapshots{$id}->{parent}->$snapshots{$id}->{id} ";
                print "\t$filesystem/$snapshots{$id}->{path}";
                print "\tEXCL:".pretty_bytes($snapshots{$id}->{excl_size});
                print " / Total(" . pretty_bytes($snapshots{$id}->{app_size}) . ")\n";
            }
    }
    return (%snapshots);
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
#   Packages
#package Filesystem;
#sub new {
#   my $class = shift;
#   my $self = {
#       label => shift,
#       uuid => shift,
#       mountpoint => shift
#   };
#   bless $class, $self;
#   return $self;
#}
package Snapshot;
sub new {
    my $class = shift;
    my $self = {
        id => shift,
        parent => shift,
        path => shift,
        excl_size => shift,
        app_size => shift
    };
    bless $self, $class;
    return $self;
}


