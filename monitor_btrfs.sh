#!/bin/bash

PASSES=100
PAUSE=300
INTERVAL=5
if [[ "$(whoami)" = "root" ]]; then
	SUDO=""
else
	SUDO="sudo "
fi

while [[ true ]]; do
	clear
	date
	# Rescan the pools inside the loop
	POOLS=$(mount | grep btrfs | cut -d' ' -f3)
	df -h / "$POOLS"
	/home/odaiwai/src/backup_and_file_scripts/btrfs_fsstats.pl
	for POOL in $POOLS; do
		CMD="btrfs scrub status $POOL"
		echo -n "# $CMD: "
		RESULT=$($CMD)
		SCRUB_STATUS=$($CMD | grep -c unning)
		SCRUB_RESULT=$($CMD | grep summary)
		if [[ $SCRUB_STATUS -gt 0 ]]; then
			echo "Running..."
			echo "$RESULT"
		else
			echo "Finished: $SCRUB_RESULT"
		fi

		CMD="btrfs balance status $POOL"
		RESULT=$($CMD)
		BAL_STATUS=$($CMD | grep -c unning)
		if [[ $BAL_STATUS -gt 0 ]]; then
			echo "$RESULT"
		fi
	done

	sensors | grep -E '(Core|[0-9]{2,} RPM)'
	# btrfs fi show /home
	for NOW in $(seq $PAUSE -$INTERVAL 0); do
		echo -ne "sleeping for $NOW seconds...\r"
		sleep $INTERVAL
	done
	echo
done
