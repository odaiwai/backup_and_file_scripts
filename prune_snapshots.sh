#!/bin/bash

# Scipt to make sure there's a copy of everything over on /backup
# and prune older snapshots as appropriate

# Make sure all the volumes are up to date on /backup
./send_all_subvols.pl 

btrfs subvol delete --commit-each /home/BACKUP.2019112[4-9]*
