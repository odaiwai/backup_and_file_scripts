#!/bin/bash

# Scipt to make sure there's a copy of everything over on /backup
# and prune older snapshots as appropriate

# Make sure all the volumes are up to date on /backup
# ./send_all_subvols.pl

# Array of last days of month:
declare -a last_days=("0131" "0228" "0229" "0330" "0430" "0531" "0630" \
                      "0731" "0831" "0930" "1031" "1130" "1231")
BASEDIR="/home/BACKUP"
for year in $(seq 2019 2023); do
    for month in $(seq -f'%02.0f' 1 12); do
        for day in $(seq -f '%02.0f' 1 31); do
            # If the date is in the list of last days:
            if [[ "${last_days[*]}" =~ "$month$day" ]]; then
                echo "Saving $year$month$day"
            else
                echo "Pruning... $year$month$day..."
                echo "btrfs subvol delete --commit-each $BASEDIR.$year$month$day\_*"
                echo $?
            fi
        done
    done
done
