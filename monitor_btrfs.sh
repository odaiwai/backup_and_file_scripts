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
		CMD="btrfs scrub status $POOL"
		echo -n "# $CMD: "
		RESULT=`$CMD`
		SCRUB_STATUS=`$CMD | grep unning | wc -l`
		SCRUB_RESULT=`$CMD | grep summary`
		if [[ $SCRUB_STATUS -gt 0 ]]
		then
			echo "Running..."
			echo "$RESULT"
		else
			echo "Finished: $SCRUB_RESULT"
		fi
	done

	echo -n "sleeping for $PAUSE seconds..."
	sleep $PAUSE
	echo
done
