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
	# lines look like:
	# Jul 15 17:17:39 gizmo journal[27439]: Couldn't create PopplerDocument from uri:'file:///home/odaiwai/Documents/Transport_Planning/2005_nsbt/invoices/nsbt-invoice-001.pdf', PDF document is damaged
	# Jul 15 17:17:39 gizmo journal[27439]: Couldn't create PopplerDocument from uri:'file:///home/odaiwai/Documents/mobile_phones/20111205_collect_phone_bills/pdf/20130704_60516148_detailed_call_record.pdf', PDF document is damaged
	# Jul 15 17:17:41 gizmo journal[27439]: Couldn't create PopplerDocument from uri:'file:///home/odaiwai/Documents/Transport_Planning/20130901_palestine_masterplan/04_data_collections/ftp.systematica.net/01_DATA%20WORK/01%20-%20CV%20(Non%20Key%20Experts)/12_Ibtisam%20Husary/BA_accounting_major_certificates.pdf', PDF document is damaged
	my $line = shift;
	my $filename = 'nil';
	#print "\t$line\n" if $verbose;
	if ( $line =~ /uri:'file:\/\/(.*)',/ ){
		$filename = $1;
		# This filename is unescaped
	}
	return $filename;
}
