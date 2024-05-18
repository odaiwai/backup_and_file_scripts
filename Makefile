DY_TARGET = /etc/cron.daily
WK_TARGET = /etc/cron.weekly
SOURCE = $(shell pwd)
DAILY_FILES = make_backup_btrfs.pl make_backup_ext4.pl make_btrfs_daily_snapshot.pl

WEEKLY_FILES = 98-btrfs-balance-scrub.sh

all: daily weekly
	@echo "Finished."

.PHONY: make
daily:
	@echo "Installing the utilities to $(DY_TARGET)"
	@for FILE in $(DAILY_FILES); \
			do \
				echo -e "\tInstalling $$FILE to $(DY_TARGET)"; \
				sudo rm -f $(DY_TARGET)/$$FILE; \
				sudo ln -s $(SOURCE)/$$FILE $(DY_TARGET); \
			done

weekly:
	@echo "Installing the utilities to $(WK_TARGET)"
	@for FILE in $(WEEKLY_FILES); \
			do \
				echo -e "\tInstalling $$FILE to $(WK_TARGET)"; \
				sudo rm -f $(WK_TARGET)/$$FILE; \
				sudo ln -s $(SOURCE)/$$FILE $(WK_TARGET); \
			done
