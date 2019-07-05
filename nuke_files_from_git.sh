#!/bin/bash

# script to nuke a file from the repo.
FILE="$1"
echo "Nuking $FILE from repository..."

git filter-branch --force --index-filter "git rm --cached --ignore-unmatch $FILE" --prune-empty --tag-name-filter cat -- --all
