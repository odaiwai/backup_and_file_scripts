#!/bin/bash

# Watch the initial qgroups for changes
watch -d "btrfs qgroup show --raw /home/ "
