#!/bin/bash

POOLS=`mount| grep btrfs | cut -d' ' -f3`

PASSES=100
PAUSE=60
I_AM=`whoami`
if [[ $I_AM = "root" ]]
then
		SUDO=""
else
		SUDO="sudo "
fi

while [[ true ]]
do
	clear
	date
	df -h $POOLS
	/home/odaiwai/src/backup_and_file_scripts/btrfs_fsstats.pl
	for POOL in $POOLS
	do
		echo "# btrfs scrub status $POOL:"
		btrfs scrub status $POOL
	done

	echo -n "sleeping for $PAUSE seconds..."
	sleep $PAUSE
	echo
done
