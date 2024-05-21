#!/bin/bash

declare -i PASSES=-1 # Infinite
declare -i SLEEP=300
declare -i INTERVAL=5
I_AM=$(whoami)
if [[ $I_AM = "root" ]]; then
	SUDO=""
else
	SUDO="sudo "
fi

# Parse any arguments
ARGS=()
while [[ $# -gt 0 ]]; do
	case $1 in
	-i | --interval)
		INTERVAL=$2
		shift
		shift
		;;
	-s | --sleep)
		SLEEP=$2
		shift
		shift
		;;
	-p | --passes)
		PASSES=$2
		shift
		shift
		;;
	*)
		ARGS+=("$1")
		shift
		;;
	esac
done

# The main Loop
declare -i PASS=$PASSES
while [[ $PASS -ne 0 ]]; do
	clear
	echo -e "Interval:\t$INTERVAL\tSleep:\t$SLEEP\tRemaining:\t$PASS/$PASSES\tRunning as:\t$I_AM"
	date
	# Rescan the pools inside the loop
	POOLS=$(mount | grep btrfs | cut -d' ' -f3)
	# Can't double quote below, as it concatenates multiple pools.
	df -h / $POOLS
	$SUDO /home/odaiwai/src/backup_and_file_scripts/btrfs_fsstats.pl
	for POOL in $POOLS; do
		CMD="$SUDO btrfs scrub status $POOL"
		echo -n "# $CMD: "
		RESULT=$($CMD)
		SCRUB_STATUS=""
		SCRUB_RESULT=""
		BAL_STATUS=0
		# Process the RESULT in a pipe to avoid running $CMD twice.
		while read -r line; do
			# echo "LINE: $line"
			case "$line" in
			*Status*)
				SCRUB_STATUS=$(echo "$line" | sed 's/\s\+/ /')
				if [[ $line =~ "running" ]]; then
					BAL_STATUS=1
				fi
				;;
			*Error*)
				SCRUB_RESULT=$(echo "$line" | sed 's/\s\+/ /')
				;;
			esac
		done <<<"$RESULT"
		echo "$SCRUB_STATUS: $SCRUB_RESULT"
		if [[ $BAL_STATUS -gt 0 ]]; then
			echo "$RESULT"
		fi
	done

	# Show the sensors: CPU and Fans only. Others not so reliable
	sensors | grep -E '(Core|[0-9]{2,} RPM)'

	# btrfs fi show /home
	for NOW in $(seq $SLEEP -$INTERVAL 0); do
		echo -ne "sleeping for $NOW seconds...\r"
		sleep $INTERVAL
	done
	echo

	# Decrement the passes
	if [[ $PASSES -gt 0 ]]; then
		PASS=$((PASS - 1))
	fi
done
