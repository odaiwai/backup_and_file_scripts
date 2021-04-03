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
# 20180821 - changed the algorithm:
#   - Take a snapshot
#   - Send all local snapshots if the backup vol is available, and they're not already there
#   - trim the local snspshots if required
#
# 20201121:  Backing up to a remote machine
# https://www.kubuntuforums.net/showthread.php/72676-Backing-up-to-a-networked-computer-using-BTRFS-and-SSH
#	- Need passwordless SSH Access
#	- change the send receive pair to be something like: 
#		btrfs send -q -p $last_backup $this_backup | ssh $remote_host "btrfs receive $remote"
my $for_real = 1;
my $verbose = 0;
my $first_run = 0;
my $local = "/home";   # Default
my $remote = "/backup";# Default
my $prefix = "BACKUP"; # Default
my $localTZ = "Asia/Hong_Kong";
my $date = DateTime->now(time_zone => $localTZ);
my $timestamp = $date->strftime("%Y%m%d_%H%M");

while (my $arg = shift @ARGV) {
    if ( $arg =~ /local/ ) { $local = shift;}
    if ( $arg =~ /remote/ ) { $remote = shift;}
    if ( $arg =~ /prefix/ ) { $prefix = shift;}
    if ( $arg =~ /verbose/ ) { $verbose = 1;}
}

print "Backing up from $local to $remote as $prefix\n" if $verbose;

my $backup_vol_present = `df $remote | wc -l`;
if ($backup_vol_present == 0) {
    print "Backup Volume not present. Cannot Send Snapshots.\n" if $verbose;
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

# Figure out our current state:
my $last_backup = $local ."/" . return_latest_backup($local, $prefix);
my $last_remote = $remote ."/" . return_latest_backup($remote, $prefix);
my $this_backup = "$local/$prefix.$timestamp";

print "Last Backup: $last_backup\n" if $verbose;
print "Last Remote: $last_remote\n" if $verbose;
print "This Backup: $this_backup\n" if $verbose;

# Algorithm taken from https://btrfs.wiki.kernel.org/index.php/Incremental_Backup
#
# Stage 1
# check if the directory snapshot exists, if not we have to create it
# if the read only subvol $local/$prefix doesn't exist, make it
printlog ($log, "1. making a local backup...");
if ( !(-d $last_backup)) {
    printlog( $log, "\t1.1 $last_backup doesn't exist: making initial backup of $local");
    my $result = do_cmd("btrfs subvolume snapshot -r $local $this_backup");
    $result = do_cmd("sync");
    $last_backup = $this_backup;
} else {
    printlog ($log, "\t1.2 $last_backup already exists.");
}

# Stage 2 if $local/$prefix exists and $remote$local/$prefix doesn't, send|receive it
printlog ($log, "2. Check if $last_backup exists and is on $remote.");
if ( (-d $last_backup) && !(-d $last_remote) ) {
    #Copy to $remote
    printlog( $log, "\t2.1 Backup only exists locally: sending...");
    my $result = do_cmd("btrfs send -q $last_backup | btrfs receive $remote");
} else {
    printlog ($log, "\t2.1.1 $last_remote exists.");
}

# Stage 3: if both $local/$prefix and $remote$local/$prefix exist do an incremental backup
# This is what will happen after every initial backup
printlog ($log, "3. Check if $last_backup and $last_remote both exist.");
if ( -d ($last_backup) && -d ("$last_remote") ) {
    # incremental backup
    printlog ($log, "\t3.1 Local and Remote Backups Exist: making incremental btrfs backup of $local...");
    my $result = do_cmd("btrfs subvolume snapshot -r $local $this_backup");
    $result = do_cmd("sync");
    $result = do_cmd("btrfs send -q -p $last_backup $this_backup | btrfs receive $remote");
    $result = do_cmd("btrfs subvolume list $local");
    if ( (-d $last_backup) and (-d $this_backup)) {
        # clean up and increment our backup
        printlog ($log, "3.1.1 Local Backup has old and new versions: keeping this one on $local");
        # Leave the snapshots alone - for the moment - we can manage them later.
        #$result = do_cmd("btrfs subvolume delete $last_backup");
        #$result = do_cmd("mv $this_backup $last_backup");
    }
    $result = do_cmd("btrfs subvolume list $remote");
    if ( (-d "$remote/$prefix") and (-d "$remote/$prefix.$timestamp")) {
        # and clean it up from the backup as well
        printlog ($log, "3.1.2 Remote has old and new backups: cleaning up $remote...");
        #$result = do_cmd("btrfs subvolume snapshot -r $remote/$prefix $remote/$prefix.$timestamp");
        #$result = do_cmd("btrfs subvolume delete $remote/$prefix");
        #$result = do_cmd("mv $remote/$prefix-new $remote/$prefix");
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

sub return_all_backups {
    # Get a list of all the subvols on a specified volume with a particular prefix
    my $volume = shift;
    my $prefix = shift;
    my @subvols = `btrfs subvol list $volume`;
    my %subvols;
    #print "Found $#subvols on $volume\n" if $verbose;
    foreach my $subvol (@subvols) {
        chomp $subvol;
        if ( $subvol =~ /$prefix.([0-9_]+)/ ) {
            my $subvol_timestamp = $1;
            $subvols{$subvol_timestamp} = "$prefix.$subvol_timestamp";
        }
    }
    return %subvols;
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
    return $prefix . "." . $last_timestamp;
}
