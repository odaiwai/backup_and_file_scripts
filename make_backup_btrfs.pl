#!/usr/bin/perl
use strict;
use warnings;
use DateTime;

# 20150710: This should really check if the backup drive is available
# 20151121: changed to perl
# 20160102: this has stopped working, probably as there's some disconnect
# 	    with the parent ID of the subvolumes
# 20160828: try to enhance the subvolume backups to work properly
# 20160929: check for the existence of the /backups volume
# 20161208 - Add date functionality
#
my $for_real = 1;
my $verbose = 1;
my $first_run = 0;
my $local = "home";
my $remote = "backup";
my $localTZ = "Asia/Hong_Kong";
my $date = DateTime->now(time_zone => $localTZ);
my $timestamp = $date->strftime("%Y%m%d_%H%M");

my $backup_vol_present = `df | grep backup | wc -l`;
if ($backup_vol_present == 0) {
	print "Backup Volume not present. Aborting.\n" if $verbose;
	exit;
}
my $logfile = "/root/backups/backup.log";
open ( my $log, ">", $logfile) or die "Can't open $logfile\n";

if ($first_run) {
	# Nuke the backups and start again
	printlog($log, "First Run: deleting the backups!");
	my $result = do_cmd("btrfs subvolume delete /$remote/BACKUP");
	$result = do_cmd("btrfs subvolume delete /$local/BACKUP");
}

# Algorithm taken from https://btrfs.wiki.kernel.org/index.php/Incremental_Backup
#
# Stage 1
# check if the directory snapshot exists, if not we have to create it
# if the read only subvol $local/BACKUP doesn't exist, make it
printlog ($log, "1. Checking if /$local/BACKUP exists...");
if ( !(-d "/$local/BACKUP")) {
	printlog( $log, "\t1.1 /$local/BACKUP doesn't exist: making initial backup of /$local");
	my $result = do_cmd("btrfs subvolume snapshot -r /$local /$local/BACKUP");
	$result = do_cmd("sync");
} else {
	printlog ($log, "\t1.2 /$local/BACKUP already exists.");
}

# Stage 2 if /$local/BACKUP exists and /$remote/$local/BACKUP doesn't, send|receive it
printlog ($log, "2. Check if /$local/BACKUP exists and /$remote/BACKUP doesn't.");
if ( (-d "/$local/BACKUP") && !(-d "/$remote/BACKUP") ) {
	#Copy to $remote 
	printlog( $log, "\t2.1 Backup only exists locally: sending...");
	my $result = do_cmd("btrfs send /$local/BACKUP | btrfs receive /$remote");
} 
# Stage 3: if both $local/BACKUP and $remote$local/BACKUP exist do an incremental backup
# This is what will happen after every initial backup
printlog ($log, "3. Check if /$local/BACKUP and /$remote/BACKUP both exist.");
if ( -d ("/$local/BACKUP") && -d "/$remote/BACKUP") {
	# incremental backup
	printlog ($log, "\t3.1 Local and Remote Backups Exist: making incremental btrfs backup of /$local...");
	my $result = do_cmd("btrfs subvolume snapshot -r /$local /$local/BACKUP-new");
	$result = do_cmd("sync");
	$result = do_cmd("btrfs send -p /$local/BACKUP /$local/BACKUP-new | btrfs receive /$remote");
	$result = do_cmd("btrfs subvolume list /$local");
	if ( (-d "/$local/BACKUP") and (-d "/$local/BACKUP-new")) { 
		# clean up and increment our backup
		printlog ($log, "3.1.1 Local Backup has old and new versions: cleaning up /$local");
		$result = do_cmd("btrfs subvolume delete /$local/BACKUP");
		$result = do_cmd("mv /$local/BACKUP-new /$local/BACKUP");
	}
	$result = do_cmd("btrfs subvolume list /$remote");
	if ( (-d "/$remote/BACKUP") and (-d "/$remote/BACKUP-new")) { 
		# and clean it up from the backup as well
		printlog ($log, "3.1.2 Remote has old and new backups: cleaning up /$remote...");
		$result = do_cmd("btrfs subvolume snapshot -r /$remote/BACKUP /$remote/BACKUP.$timestamp");
	 	$result = do_cmd("btrfs subvolume delete /$remote/BACKUP");
		$result = do_cmd("mv /$remote/BACKUP-new /$remote/BACKUP");
	}
}

printlog ($log, "4. Finished.");


## subs
sub do_cmd {
	my $command = shift;
	printlog ($log, "\t$command");
	my $tmpfile = "~/tmp/backup_tmp.log";
	my $result = "dry_run";
	$result = `$command 1>$tmpfile 2>&1` if $for_real;
	$result = `cat $tmpfile >> $logfile` if $for_real; 
	printlog ($log, "\tResult: $result");
	return $result;
}
sub printlog {
	# print to STDOUT and to the Log File
	my $logfh = shift;
	my $statement = shift;
	print $logfh "$statement\n";
	print "$statement\n" if $verbose;
	return 1;
}

