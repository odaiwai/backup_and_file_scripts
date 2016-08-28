#!/usr/bin/perl

# 20150710: This should really check if the backup drive is available
# 20151121: changed to perl
# 20160102: this has stopped working, probably as there's some disconnect
# 	    with the parent ID of the subvolumes
#
my $for_real = 1;
my $verbose = 1;
my $first_run = 0;
my $local = "/home";
my $remote = "/backup";

my $logfile = "/root/backups/backup.log";
open ( my $log, ">", $logfile) or die "Can't open $logfile\n";

if ($first_run) {
	# Nuke the backups and start again
	printlog($log, "First Run: deleting the backups!");
	my $result = do_cmd("btrfs subvolume delete /backup/home/BACKUP");
	$result = do_cmd("btrfs subvolume delete /home/BACKUP");

}

# check if the directory snapshot exists, if not we have to create it
# steps taken from https://btrfs.wiki.kernel.org/index.php/Incremental_Backup
# if the read only subvol /home/BACKUP doesn't exist, make it
printlog ($log, "1. Checking if 
if ( !(-d "/home/BACKUP")) {
	printlog( $log, "1. /home/BACKUP doesn't exist: making initial backup of /home");
	my $result = do_cmd("btrfs subvolume snapshot -r /home/BACKUP");
	$result = do_cmd("sync");
}
# if /home/BACKUP exists and /backup/home/BACKUP doesn't, send|receive it
if ( (-d "/home/BACKUP") && !(-d "/backup/home/BACKUP") ) {
	#Copy to /backup 
	printlog( $log, "2. Backup only exists locally: sending...");
	my $result = do_cmd("btrfs send /home/BACKUP | btrfs receive /backup/home");
} 
# if both /home/BACKUP and /backup/home/BACKUP exist do an incremental backup
if ( -d ("/home/BACKUP") && -d "/backup/home/BACKUP") {
	# incremental backup
	printlog ($log, "3. Local and Remote Backups Exist: making incremental btrfs backup of /home...");
	my $result = do_cmd("btrfs subvolume snapshot -r /home /home/BACKUP-new");
	$result = do_cmd("sync");
	$result = do_cmd("btrfs send -p /home/BACKUP /home/BACKUP-new | btrfs receive /backup/home");
	if ( (-d "/home/BACKUP") and (-d "/home/BACKUP-new")) { 
		# clean up and increment our backup
		printlog ($log, "4. Local Backup has old and new versions: cleaning up /home");
		$result = do_cmd("btrfs subvolume delete /home/BACKUP");
		$result = do_cmd("mv /home/BACKUP-new /home/BACKUP");
	}
	if ( (-d "/backup/home/BACKUP") and (-d "/backup/home/BACKUP-new")) { 
		# and clean it up from the backup as well
		printlog ($log, "5. Remote has old and new backups: cleaning up /backup...");
		$result = do_cmd("btrfs subvolume delete /backup/home/BACKUP");
		$result = do_cmd("mv /backup/home/BACKUP-new /backup/home/BACKUP");
	}
}

printlog ($log, "6. Finished.");
## subs
sub do_cmd {
	my $command = shift;
	printlog ($log, "\t$command");
	my $tmpfile = "~/tmp/$0.log";
	my $result = "dry_run";
	$result = `time $command 1>$tmpfile 2>&1` if $for_real;
	$result = `cat $tmpfile >> $logfile` if $for_real; 
	printlog ($log, "\tResult: $result");
	return $result;
}
sub printlog {
	# print to STDOUT and to the Log File
	my $logfh = shift;
	my $statement = shift;
	print $logfh "$statement\n";
	print "$statement\n";
	return 1;
}

