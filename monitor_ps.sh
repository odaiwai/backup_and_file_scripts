#!/bin/bash
#
# Monitor the btrfs check process
DATE=$(date +"%Y%m%d %H:%M:%S")
FIELDS="user,pid,vsize,rssize,pcpu,pmem,tty,stat,start,time,etime,command"
PROCESS=$(ps -o $FIELDS | grep -i btrfs | sed '/grep/d')
echo "$DATE: $PROCESS"

# ps  -o user,pid,vsize,rssize,pcpu,pmem,tty,stat,start,time,etime,command
