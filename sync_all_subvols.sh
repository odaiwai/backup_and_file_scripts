#!/bin/bash

for filesystem in home backup
do
	for subvol in `ls /$filesystem/ | grep BACKUP`
		do echo $filesystem $subvol
		sudo btrfs subvol sync /home/$subvol
	done
done
