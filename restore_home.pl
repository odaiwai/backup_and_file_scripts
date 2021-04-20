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

my $src_dir = "/backup/BACKUP.20210415_0338";
my $home_dir = "/home";
my @dirs = return_dirs();

for my $dir (@dirs) {
	chomp $dir;

	print "copying $src_dir/$dir/ to $home_dir/$dir ...\n";
	my $cmd = "rsync $rsync_options $src_dir/$dir/ $home_dir/$dir";
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
		push @dirs, "conor/windows_backup";
		push @dirs, "odaiwai/Downloads/Wii";
		push @dirs, "odaiwai/Music/iTunes";
		push @dirs, "odaiwai/Pictures/Ricoh_GX200";
		push @dirs, "odaiwai/Music/aiff_music";
		push @dirs, "odaiwai/Documents/Transport_Planning";
		push @dirs, "odaiwai/Pictures/iPhoto Library";
		push @dirs, "odaiwai/Music/SXSW_2012_Showcasing_Artists_Part2";
		push @dirs, "odaiwai/Pictures/Photos Library.photoslibrary";
		push @dirs, "odaiwai/Music/SXSW_2006_Showcasing_Artists_-_Release_1";
		push @dirs, "odaiwai/Music/iTunes";
	}
	return @dirs;
}
