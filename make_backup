#!/bin/sh

# 20150710: This should really check if the backup drive is available

DIRS=""
DIRS="$DIRS etc var/log var/www var/named root boot usr/local var/spool/cron "
DIRS="$DIRS var/spool/mail"
DIRS="$DIRS home/roxanne"
DIRS="$DIRS home/conor"
DIRS="$DIRS home/iob"
DIRS="$DIRS home/sandra"
#DIRS="$DIRS home/odaiwai/Documents"
#DIRS="$DIRS home/odaiwai/Pictures"
#DIRS="$DIRS home/odaiwai/Music"
#DIRS="$DIRS home/odaiwai/Movies"
DIRS="$DIRS home/odaiwai"

# this directory is a rolling checkpoint and fills up with out of 
# date crap unless policed.  There should be 7 files in here, not 40G!
rm -rf /backup/var/lib/pgsql/data/pg_xlog/*
rm -rf /backup/etc/udev/devices/*
rm -rf /backup/etc/rhgb/temp/*
rm -rf /backup/var/lib/mlocate/*
rm -rf /backup/home/odaiwai/.bittorrent/data/ui_socket
rm -rf /backup/home/odaiwai/Downloads/*.part



#RSYNC_OPTIONS="--progress --stats --recursive --compress --times --perms --links --human-readable"
RSYNC_OPTIONS="--stats --recursive --compress --times --perms --links --human-readable --exclude=\"[Dd]ownloads\""
# rsync is incredibly slow for large copies.  Probably need more RAM
#RSYNC_OPTIONS="$RSYNC_OPTIONS --dry-run"
CP_OPTS="au"
shopt -s extglob
for DIR in $DIRS
do
	# Basic Method - using cp
	mkdir -p /backup/$DIR
	echo "Copying /$DIR/* to /backup/$DIR/"
	cp -$CP_OPTS /$DIR/*  /backup/$DIR/ 2>/dev/null
	# Method 2 - using Rsync
	#echo "rsync $RSYNC_OPTIONS /$DIR /backup/$DIR"
	#rsync $RSYNC_OPTIONS /$DIR /backup/$DIR
	#method 3 - BTRFS send/receive not all of the filesystems are btrfs!
	#?
done


