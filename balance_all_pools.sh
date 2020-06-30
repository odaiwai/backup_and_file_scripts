#!/bin/bash


POOLS=`mount| grep btrfs | cut -d' ' -f3 | tr '\n' ' '`

# defaults
LIMIT=1
PASSES=1
PAUSE=10
FOR_REAL=1
I_AM=`whoami`

# Get the arguments in pairs

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-l|--limit)
			LIMIT="$2"
			shift
			shift
			;;
		-p|--passes)
			PASSES="$2"
			shift
			shift
			;;
		-s|--sleep|--pause)
			PAUSE="$2"
			shift
			shift
			;;
		-d|--dryrun|--dry-run)
			FOR_REAL=0
			shift
			;;
	*)
			shift
			;;
	esac
done

SUDO="sudo"
if [[ $I_AM = "root" ]]
then
		SUDO=""
fi

# Do the deed
echo "Performing $PASSES balances on [$POOLS] (limit $LIMIT) with $PAUSE second pauses as user '$I_AM'. Dry Run Status: $FOR_REAL"
date

for PASS in `seq 1 $PASSES`
do
	for POOL in $POOLS
	do
		echo "Balancing $POOL, Pass $PASS/$PASSES"
		CMD="$SUDO btrfs balance start -v $POOL -dlimit=$LIMIT -mlimit=$LIMIT"
		date
		echo "$CMD"
		if [[ $FOR_REAL ]]
		then
			time $CMD
		fi
		echo "Status: $?, sleeping for $PAUSE seconds..."
		sleep $PAUSE
	done
done
