#!/usr/bin/perl
use strict;
use warnings;
use DateTime;

# 20150710: This should really check if the backup drive is available
# 20151121: changed to perl
# 20160102: this has stopped working, probably as there's some disconnect
#       with the parent ID of the subvolumes
# 20160828: try to enhance the subvolume backups to work properly
# 20160929: check for the existence of the /backups volume
# 20161208 - Add date functionality
#
my $for_real = 0;
my $verbose = 1;
my $first_run = 0;
my $local = "/home";   # Default
my $remote = "/backup";# Default
my $prefix = "BACKUP"; # Default
my $localTZ = "Asia/Hong_Kong";
my $date = DateTime->now(time_zone => $localTZ);
my $timestamp = $date->strftime("%Y%m%d_%H%M");

while (my $arg = shift @ARGV) {
    if ( $arg eq "--local" ) { $local = shift;}
    if ( $arg eq "--remote" ) { $remote = shift;}
    if ( $arg eq "--prefix" ) { $prefix = shift;}
}

print "Backing up from $local to $remote as $prefix\n" if $verbose;

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
    my $result = do_cmd("btrfs subvolume delete $remote/$prefix");
    $result = do_cmd("btrfs subvolume delete $local/$prefix");
}
my $last_backup = $local ."/" . return_latest_backup($local, $prefix);
my $last_remote = $remote ."/" . return_latest_backup($remote, $prefix);
my $this_backup = "$local/$prefix.$timestamp";

print "Last Backup: $last_backup\n" if $verbose;
print "Last Remote: $last_remote\n" if $verbose;
print "This Backup: $this_backup\n" if $verbose;
exit;

# Algorithm taken from https://btrfs.wiki.kernel.org/index.php/Incremental_Backup
#
# Stage 1
# check if the directory snapshot exists, if not we have to create it
# if the read only subvol $local/$prefix doesn't exist, make it
printlog ($log, "1. Checking if $last_backup exists...");
if ( !(-d $last_backup)) {
    printlog( $log, "\t1.1 $last_backup doesn't exist: making initial backup of $local");
    my $result = do_cmd("btrfs subvolume snapshot -r $local $last_backup");
    $result = do_cmd("sync");
} else {
    printlog ($log, "\t1.2 $last_backup already exists.");
}

# Stage 2 if $local/$prefix exists and $remote$local/$prefix doesn't, send|receive it
printlog ($log, "2. Check if $last_backup exists and $remote/$prefix doesn't.");
if ( (-d $last_backup) && !(-d "$remote/$prefix") ) {
    #Copy to $remote
    printlog( $log, "\t2.1 Backup only exists locally: sending...");
    my $result = do_cmd("btrfs send $last_backup | btrfs receive $remote");
}
# Stage 3: if both $local/$prefix and $remote$local/$prefix exist do an incremental backup
# This is what will happen after every initial backup
printlog ($log, "3. Check if $last_backup and $remote/$prefix both exist.");
if ( -d ($last_backup) && -d "$remote/$prefix") {
    # incremental backup
    printlog ($log, "\t3.1 Local and Remote Backups Exist: making incremental btrfs backup of $local...");
    my $result = do_cmd("btrfs subvolume snapshot -r $local $this_backup");
    $result = do_cmd("sync");
    $result = do_cmd("btrfs send -p $last_backup $this_backup | btrfs receive $remote");
    $result = do_cmd("btrfs subvolume list $local");
    if ( (-d $last_backup) and (-d $this_backup)) {
        # clean up and increment our backup
        printlog ($log, "3.1.1 Local Backup has old and new versions: cleaning up $local");
        $result = do_cmd("btrfs subvolume delete $last_backup");
        $result = do_cmd("mv $this_backup $last_backup");
    }
    $result = do_cmd("btrfs subvolume list $remote");
    if ( (-d "$remote/$prefix") and (-d "$remote/$prefix.$timestamp")) {
        # and clean it up from the backup as well
        printlog ($log, "3.1.2 Remote has old and new backups: cleaning up $remote...");
        #$result = do_cmd("btrfs subvolume snapshot -r $remote/$prefix $remote/$prefix.$timestamp");
        $result = do_cmd("btrfs subvolume delete $remote/$prefix");
        $result = do_cmd("mv $remote/$prefix-new $remote/$prefix");
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

sub return_latest_backup {
    # give the most recent snapshot on a specified volume with a particular prefix
    my $volume = shift;
    my $prefix = shift;
    my @subvols = `btrfs subvol list $volume`;
    #print "Found $#subvols on $volume\n" if $verbose;
    my $last_timestamp = "19700101_0000"; # in the unlikely event of earlier backups...
    foreach my $subvol (@subvols) {
        chomp $subvol;
        if ( $subvol =~ /$prefix.([0-9_]+)/ ) {
            my $subvol_timestamp = $1;
            if ( $subvol_timestamp gt $last_timestamp ) {
                $last_timestamp = $subvol_timestamp;
                #print "$subvol: $subvol_timestamp, $last_timestamp\n" if $verbose;
            }
        }
    }
    return $prefix . "_" . $last_timestamp;
}
