# Fix failing /dev/sdc
#
## problem 2021/04

/home has a failing drive (sdc). Added another drive to btrfs delete, but the process failed and now I have four drives in the /home pool.


I have a backup of /home on /backup
Actions so far:

strategy 1:
0. run a _scrub start /home_ and note where errors occur.  
1. Delete those files from the /home device (including from all snapshots)
2. keep a list of them to restore from /backup later
3. run _btrfs device delete /dev/sdc /home_ and note is any errors.
4. delete the files causing the read error on SDC and delete them from all 
   snapshots on /home (files causing the problem can be found using scrub)
5. iterate until done, or this approach isn't working anymore.

results:
	The files causing issues were deleted, but _btrfs device delete /dev/sdc
	/home_ fails with an error that returns no helpful results:

    [root@gizmo odaiwai]# btrfs device delete /dev/sdc /home
    ERROR: error removing device '/dev/sdc': Structure needs cleaning

However, _btrfs scrub /home_ claims no errors, and the system seems usable at
the moment.

strategy 2:
0. buy a large hard drive capable of holding the entire _/home_ device. (12tb
   min)
1. Mount this in the box - need to temporarily remove/disconnect the /backup drives
2. Copy everything on home to this using btrfs send/receive
3. Reformat the /home drives without the failing one
4. Copy everything back from the large new drive.
5. remove the new drive, reconnect the /backup

