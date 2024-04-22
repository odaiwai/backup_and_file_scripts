#!/bin/bash
#
# script to make a list of all btrfs filesystems, balance them and start a scrub

btrfs=/sbin/btrfs

#pools="/home /backup"
pools=`mount | grep btrfs | cut -d" " -f3`
# Balancing the FS can take a long time, and use a Lot of RAM.  Only do it while in attendance.

if [ "$pools" != "" ] ; then
    echo Found these pools: $pools

    for pool in $pools; do
        echo "Starting $btrfs scrub start $pool"
        # turn off the quotas before balancing
        $btrfs quota disable $pool
        $btrfs filesystem sync $pool
        # Balance Data and Metadata - empty blocks only possibly unnecessary
        $btrfs balance start -musage=0 -dusage=0 -v $pool
        # Balance Data limit the number of of Blocks. Metadata is automatic now.
        $btrfs balance start -dlimit=20 -v $pool
        # Start the Scrub
        $btrfs scrub start $pool
    done

    echo "BTRFS automatic scrub start done.  Use '$btrfs scrub status $pool' to see progress."
fi

# Wait for the pools to finish and reenable the quotas?
FINISHED=0
