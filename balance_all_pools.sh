#!/bin/bash



# defaults
LIMIT=1
PASSES=1
PAUSE=10
USAGE=0
FOR_REAL=1
POOLS=""
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
		-u|--usage)
			USAGE="$2"
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
		\/*)
			POOLS="$key $POOLS"
			shift
			;;
	*)
			shift
			;;
	esac
done
echo $POOLS
if [ -z $POOLS ]
then
	POOLS=`mount| grep btrfs | cut -d' ' -f3 | tr '\n' ' '`
fi

SUDO="sudo"
if [ $I_AM = "root" ]
then
		SUDO=""
fi

# Do the deed
echo "Performing $PASSES balances on [$POOLS] (limit $LIMIT usage $USAGE) with $PAUSE second pauses as user '$I_AM'. Dry Run Status: $FOR_REAL"
date

for PASS in `seq 1 $PASSES`
do
	for POOL in $POOLS
	do
		echo "Balancing $POOL, Pass $PASS/$PASSES"
		CMD="$SUDO btrfs balance start -v $POOL -dlimit=$LIMIT -mlimit=$LIMIT -dusage=$USAGE -musage=$USAGE"
		NO_BALANCE=`$SUDO btrfs balance status $POOL | grep "No balance found" | wc -l`;
		date
		echo "$CMD"
		if [ $FOR_REAL -eq 1 ]
		then
			if [ $NO_BALANCE -eq 1 ]
			then
				time `RESULTS=`$CMD``
				echo $RESULTS | tail -1 | sed 's/^\(.* relocate \)\([0-9]\+\) out of \([0-9]\+\) chunks/\2, \3/'
			else
				echo "Balance already running on $POOL."
			fi
		fi
	done
	if [[ $PASS -lt $PASSES ]]
	then
		# Don't pause on the last pass...
		echo "Status: $?, sleeping for $PAUSE seconds..."
	fi
	sleep $PAUSE
done
