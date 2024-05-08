# Recover from SUBVOL delete with Quotas enabled

The situation:
I have /home as 2x6TB hdd in BTRFS Raid0/data, RAID1/MData. I make a daily snapshot by cronjob overnight, so there's about 1000 snapshots on it. These snapshots go in ```/home/BACKUP.yyyymmdd_hhmm```, with the volume name as the date and time of creation.

 One day a little while back, I enabled quotas: ```btrfs quota enable /home```[1], and it started doing its thing.  I did a ```btrfs subvol delete /home/BACKUP....``` (one of the earlier backups, about 117MB exclusive, according to the qgroup), and realised it would take a while to complete, so I left it alone.  Later that same day, there was a power outage, and when I restarted the box, everything came up as normal, but a ```btrfs-cleaner``` process started that eventually took all of memory (32GB) and then eventually made the machine non-responsive.

I rebooted in single user with ```/home``` unmounted, set up 128GB of swap using a USB 3.0 flashdrive, then ran ```btrfs check -p -Q /home```. It took 75 hours to run, and used a max of about 80GB of RAM+Swap, and reported no errors.  I tried to mount the drive as normal again, and once more ```btrfs-cleaner``` spins up, takes all memory and makes everything unresponsive, with constant ```OOM``` killings of all the processes. It doesn't use swap much, which is interesting.  All through this, [```btrfs-orphan-cleanup-progress```](https://github.com/knorrie/python-btrfs/blob/master/bin/btrfs-orphan-cleaner-progress) reports that there is one orphan to be deleted, corresponding to the snapshot I deleted, and it doesn't go away.

I can mount the volume read-only and with ```rescue-all``` with no drama, and nothing dramatic appears in the system logs.

I cannot run ```btrfs quota disable /home``` as the command doesn't return, and the system eventually locks up when mounted RW.

There was ```btrfs rescue disable-quota``` command I found on the kernel mailing list ([btrfs-progs: rescue: Add ability to disable quota offline - Patchwork](https://patchwork.kernel.org/project/linux-btrfs/patch/20180812013358.16431-1-wqu@suse.com/)), but this isn't in the modern tools and seems to have disappeared around Kernel 4.9.  I tried to patch it into ```btrfs progs```, but it doesn't seem to work, and my kernel-hacking skills are woeful.

My Questions:
 - Is there a modern tool to disable quotas from an unmounted fs?  Or is there a mount option that does it? The documentation doesn't say clearly, but is often out of date.
 - Is there any other way to work around this? My current plan is to get some more drives, make a new pair in the machine and just copy everything over from the read-only fs.

[1] This was my first mistake, don't enable quotas.

## reccomendations:
Take it to the BTRFS mailing List
[Re: BTRFS w/ quotas hangs on read-write mount using all available RAM - rev2](https://lore.kernel.org/linux-btrfs/618f7bf7-0ffd-407d-a42c-bf86199bb1e0@gmx.com/T/#t)

Advice:
*"Deleting a snapshot is super qgroup heavy, it needs to remark all*
*involved data extents for qgroup to rescan, and furthermore, the rescan*
*has to be done in just one transaction, mostly to hang the whole system.*

*That's the same thing, doing the same subvolume dropping.*

*And unfortunately there is no proper way to handle it without marking*
*qgroup inconsistent.*

*So the only way to get rid of the situation is using the newer sysfs*
*interface "/sys/fs/btrfs/<uuid>/qgroups/drop_subtree_treshold".*

*Some lower value like 2 or 3 would be good enough to address the*
*situation, which would automatically change qgroup to inconsistent if a*
*larger enough subtree is dropped."*

## Attempts:
 - Boot into single user mode
 - echo "3" > /sys/fs/btrfs/<uuid>/qgroups/drop_subtree_treshold
 - wait and watch
 - System runs out of RAM
 - Boot into single user mode
 - echo "2" > /sys/fs/btrfs/<uuid>/qgroups/drop_subtree_treshold
 - wait and watch
 - System runs out of RAM
 - Boot into single user mode with /home mounted as RO
 - echo "1" > /sys/fs/btrfs/<uuid>/qgroups/drop_subtree_treshold
 - mount /home as RW and wait
 - echo "0" > /sys/fs/btrfs/<uuid>/qgroups/drop_subtree_treshold
 - problem goes away and qgroups are marked as inconsistent.
 - `btrfs quota disable /home`

 Problem solved.

External References:
https://lore.kernel.org/linux-btrfs/9e7c4d26-81d7-4c11-b63d-33cd43b96bd6@gmx.com/T/#t
https://new.reddit.com/r/btrfs/comments/1cjqexo/removing_qgroupsquotas_from_an_unmounted_volume/

