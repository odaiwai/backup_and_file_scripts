#!/usr/bin/perl
use strict;
use warnings;
use DateTime;

my $local = "/home";   # Default
my $for_real = 1; 
my $verbose = 1; 
my $remote = "/backup";# Default
my $prefix = "BACKUP"; # Default
my $localTZ = "Asia/Hong_Kong";
my $date = DateTime->now(time_zone => $localTZ);
my $timestamp = $date->strftime("%Y%m%d_%H%M");

my $logfile = "/root/backups/backup.log";
open ( my $log, ">", $logfile) or die "Can't open $logfile\n";

my $this_backup = "$local/$prefix.$timestamp";

printlog ($log, "1. making a local backup...");
my $result = do_cmd("btrfs subvolume snapshot -r $local $this_backup");
$result = do_cmd("sync");

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
