#!/usr/bin/perl
use strict;
use warnings;

# script to repond to an error and restore a damaged file from the backup, if
# possible
#  20180716 - Dave O'Brien
my $verbose = 1;
my %filenames; 

my @list = `sudo grep "document is damaged" /var/log/messages`; 
foreach my $line (@list) {
		chomp $line;
		my $filename = filename_from_line($line);
		if ( $filename ne "nil" ) {
			#print "Filename: $filename\n";
			#if ( -e $filename) { print "\t File exists.\n"; }
			#my $result = `ls -l "$filename"`;
			#print "\t$result\n";
			$filenames{$filename}++;
		}
}
foreach my $filename (keys %filenames) {
	if ( exists($filenames{$filename}) ) {
		print "$filename ($filenames{$filename})\n";
	}
}
sub filename_from_line {
	my $line = shift;
	my $filename = 'nil';
	#print "\t$line\n" if $verbose;
	if ( $line =~ /uri:'file:\/\/(.*)',/ ){
		$filename = $1;
		# This filename is unescaped
	}
	return $filename;
}
