#!/bin/bash

# Search the backups for a file

# Store the files in an array

PATTERN="72be4321ce7f756d710e532c5912046efe2c9c"
BACKUPS=`ls /home | grep BACKUP`
PWD="odaiwai/Documents/data_analysis_and_visualisation/20200105_SARS_outbreak/.git/objects/"
ROOT="/home" #"/backup"
#ROOT="/backup"

for BACKUP in $BACKUPS
do
	FILEPATH="$ROOT/$BACKUP/$PWD"
	echo "$FILEPATH"
	tree -ifsD $FILEPATH | grep $PATTERN
	#RESULTS=(`tree -ifsD $FILEPATH | grep $PATTERN`)
	#for RESULT in  "${RESULTS[@]}" 
	#do
	#	echo $RESULT
	#done
done
