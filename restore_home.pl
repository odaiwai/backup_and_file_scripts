#!/usr/bin/perl
use strict;
use warnings;

# script to copy from /backup/home to /home
my $verbose = 1;
my $dry_run = 0;
my $do_all = 0;
my $pause = 5;
my $rsync_options = "--stats --compress --recursive --times --perms --links --human-readable --update --archive";
$rsync_options .= " --progress --info=progress2" if $verbose;
$rsync_options .= " --dry-run" if $dry_run;

my $src_dir = "/backup/BACKUP.20210415_0338/odaiwai";
my $home_dir = "/home/odaiwai";
my @dirs = return_dirs();

for my $dir (@dirs) {
	chomp $dir;
	print "copying $src_dir/$dir to $home_dir ...\n";
	my $cmd = "rsync $rsync_options $src_dir/$dir $home_dir";
	print "$cmd\n";
	my $result = `time $cmd`;
	print "$result\n";
	if ( $pause >= 0) {
		print "Waiting for $pause ...";
		sleep $pause;
		print "\n";
	}
}

#subs
sub return_dirs {
	my @dirs;
	if ( $do_all) {
		@dirs = `ls -atr $src_dir`;
	} else {
		#@dirs = qw/Documents Games Pictures RaspberryPi webcam iPhone_utilities projects/; # list of dirs to work with
		@dirs = qw/Downloads Music Pictures/; # list of dirs to work with
	}
	return @dirs;
}
