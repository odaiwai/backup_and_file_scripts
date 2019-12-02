#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: dedupe_a_file.pl
#        USAGE: ./dedupe_a_file.pl  
#  DESCRIPTION: Dedup a file across all the snapshots 
#       AUTHOR: Dave OBrien (odaiwai), odaiwai@diaspoir.net
#      CREATED: 12/02/2019 07:50:49 PM
#===============================================================================
use strict;
use warnings;
use utf8;

# Algorithm:
#	Set all of the snapshots to RW
#	Pass the file and all snapshots to duperemove
#	Wait for that to finish
#	Set all of the snapshots to RO again

