#!/usr/bin/perl
use strict;
use warnings;

# script to copy from /backup/home to /home
my $verbose = 1;
my $cp_options = "au";
$cp_options .= "v" if $verbose;

#my @dirs = `ls -tr /backup/home | sed '/odaiwai/d'`;
#my $result = copy_dirs("/backup/home", @dirs);
my @dirs2 = `ls -atr /backup/home/odaiwai`;
my $result = copy_dirs("/backup/home/odaiwai", @dirs2);

## subs
sub copy_dirs {
	my $root = shift;
	while (my $dir = shift ) {
		chomp $dir;
		print "copying $root/$dir to /home/$dir...";
		if ($dir eq "BACKUP") {
			print "$dir: Not this one\n";
		} else {
			print "\n";
			my $result = `time rsync -aHAX --progress $root/$dir /home/odaiwai`;
			print "$result\n";
		}
	}
	return 1;
}
