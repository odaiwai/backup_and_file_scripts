#!/bin/bash

# script to nuke a file from the repo.
git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch restore_list.txt' --prune-empty --tag-name-filter cat -- --all
