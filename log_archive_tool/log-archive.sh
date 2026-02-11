#!/bin/bash

#1. target directory
TARGET_DIR=$1
OPTION=$2

#warn1
if [ -z "$TARGET_DIR" ]; then
	echo "Error: Please specify the log folder to be archived"
	echo "Usage: $0 /var/log [--clear]"
	exit 1
fi

#2. DATE AND HOUR FORMAT
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="archives"
mkdir -p "$BACKUP_DIR"

ARCHIVE_NAME="$BACKUP_DIR/log_archive_${DATE}.tar.gz"

#3. tar command
echo "Archive process is executing"
tar -czf "$ARCHIVE_NAME" "$TARGET_DIR"/*.log 2>/dev/null

if [ $? -eq 0 ]; then
	#saving to log file
	echo "Archive created: $ARCHIVE_NAME - Date: $(date)" >> archive_history.txt

	#User info
	echo "Successful! The logs were saved here: $ARCHIVE_NAME"

	if [ "$OPTION" == "--clear" ]; then
		echo "⚠️  Darning: '--clear' command detected. Logs are cleaning..."

		read -p "Are you sure? (y/n): " approval
		if [ "$approval" == "y" ]; then
			for file in "$TARGET_DIR"/*.log; do
				if [ -w "$file" ]; then
					> "$file"
					echo "🧹 Cleaned: $file"
				fi
			done
			echo "✨ All log files cleaned."
		else
			echo "The process cancelled. Only archived."
		fi
	fi
else
	echo "❌ Error: Archiving failed."
	exit 1
fi
