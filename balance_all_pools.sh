#!/bin/bash

POOLS=`mount| grep btrfs | cut -d' ' -f3`
LIMIT=1
PASSES=100
PAUSE=1
I_AM=`whoami`

if [[ $I_AM = "root" ]]
then
		SUDO=""
else
		SUDO="sudo "
fi
echo "Performing $PASSES balances on $POOLS (limit $LIMIT) with $PAUSE second pauses. Running as $I_AM."
date

for PASS in `seq 1 $PASSES`
do
	for POOL in $POOLS
	do
			echo "Balancing $POOL, Pass $PASS"
			CMD="$SUDO btrfs balance start -v $POOL -dlimit=$LIMIT -mlimit=$LIMIT"
			date
			echo "$CMD"
			`time $CMD`
			echo "Status: $?, sleeping for $PAUSE seconds..."
			sleep $PAUSE
	done
done
