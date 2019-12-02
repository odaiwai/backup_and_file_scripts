#!/usr/bin/perl
use strict;
use warnings;

# 20150710: This should really check if the backup drive is available
# 20151121: changed to perl

my $verbose = 0;
my $dry_run = 0;
my @ext4dirs = qw(etc var/log var/www var/named root boot usr/local var/spool/cron var/spool/mail);

# this directory is a rolling checkpoint and fills up with out of 
# date crap unless policed.  There should be 7 files in here, not 40G!
my $result = `rm -rf /backup/var/lib/pgsql/data/pg_xlog/`;
$result = `rm -rf /backup/etc/udev/devices/*`;
$result = `rm -rf /backup/etc/rhgb/temp/*`;
$result = `rm -rf /backup/var/lib/mlocate/*`;
#$result = `rm -rf /backup/home/odaiwai/.bittorrent/data/ui_socket`;
#$result = `rm -rf /backup/home/odaiwai/Downloads/*.part`;

my $rsync_options="--progress --stats --recursive --compress --times --perms --links --human-readable";
#my $rsync_options="--stats --recursive --compress --times --perms --links --human-readable --exclude=\"[Dd]ownloads\"";
# rsync is incredibly slow for large copies.  Probably need more RAM
$rsync_options .= " --dry-run" if $dry_run;
$rsync_options .= " -v" if $verbose;
my $cp_opts="au";

#shopt -s extglob ?
# use rsync for the ext4
foreach my $dir (@ext4dirs) {
	my @cmds;
	push @cmds, "mkdir -p /backup/$dir";
	push @cmds, "rsync $rsync_options /$dir /backup/";
	for my $cmd (@cmds) {
		print "$cmd\n" if $verbose;
		my $result = `$cmd`;
		print "$result\n" if $verbose;
	}
}


sub do_cmd {
	my $command = shift;
	print "$command\n" if $verbose;
	my $result = `time $command`;
	print $result if $verbose;
	return $result;
}
print "Finished.\n" if $verbose;
#for DIR in $DIRS
#do
#	# Basic Method - using cp
#	mkdir -p /backup/$DIR
#	echo "Copying /$DIR/* to /backup/$DIR/"
#	cp -$CP_OPTS /$DIR/*  /backup/$DIR/ 2>/dev/null
#	# Method 2 - using Rsync
#	#echo "rsync $RSYNC_OPTIONS /$DIR /backup/$DIR"
#	#rsync $RSYNC_OPTIONS /$DIR /backup/$DIR
#	#method 3 - BTRFS send/receive not all of the filesystems are btrfs!
#	#?
#done


