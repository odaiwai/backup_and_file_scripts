#!/usr/bin/perl
use strict;
use warnings;

# Script to retrieve files, smallest first
# TODO:
# - Keep a Database or list of files
# - Note the status of each file (OK, partial, corrupt)
# - manually review the file list and figure out where it makes sense to persist with recovery and where it doesn't (no point in trying to recover files I can get online or recreate or just don't care about.)
# - Add ddrescue to the recovery attempts - will need a separate directory for the log files, and some organisational method for the log files. Suggest to use md5sum to create a UUIDfor each file
#
my $firstrun = 0;
my $start = 57300;
my $basedir = "/backup/home/odaiwai";
my $restore_list = "restore_list.txt";
my $result = `tree -iafs $basedir | sort -f >$restore_list` if $firstrun;
my @listfh = open (my $listfh, "<", $restore_list);
my ($total, $null) = split( " ", `wc -l $restore_list`);
my $count = 0;
open (my $outfh, ">>", "results_of_file_by_file_restore.out");
while ( my $line =<$listfh>) {
    chomp $line;
    $count ++;
    if ( $line =~ /^\[([0-9 ]+)\]\s+(.*)$/) {
        my $size = $1;
        my $filename = $2;
        $size =~ s/[ ]+//g;
        if ($size > $start and !(-d $filename)){
            print "Progress: $count/$total (". sprintf("%6.2f", ($count/$total)*100). "%) File: $size: $filename\n";
            print "LINE:$line\n";
            print $outfh "$filename, $size, ";
            my $command = "rsync --progress -aHAX \"$filename\"";
            my $destination = $filename;
            #$destination =~ s/^\/backup//;
            my @components = split "\/", $destination;
            my $base = shift @components;
            my $base2 = shift @components;
            my $last = pop @components;
            #print "$filename, $base, $base2, $last\n";
            my $new_destination = join "\/", @components;
            $command .= " \"/$new_destination/\"\n";
            print "$command \n";
            my $result = `$command`;
            print "$result\n";
            print $outfh "$result\n";
            #sleep 15;
        }
    }
}

close $outfh;
