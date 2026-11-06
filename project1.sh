#!/usr/bin/env bash

# Automated Backup System

#old backup directory path, only runs the bash
# BACKUP_DIR="$HOME/backups"

#new directory, it works with both scrips or decker file
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR" || {
    echo "Error: Cannot create backup directory"
    exit 1
}
RETENTION_FILE="$HOME/.backup_retention"
SCHEDULE_FILE="$HOME/.backup_schedule"
LOG_FILE="$BACKUP_DIR/backup.log"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
set -o pipefail

log_message()
{
    DATE=$(date +"%Y-%m-%d %H:%M:%S")

    echo "[$DATE] $1 : $2" >> "$LOG_FILE"
}

create_backup()
{
    echo "Enter source folder path:"
    read -r SOURCE

    if [ ! -d "$SOURCE" ]; then
        log_message "ERROR" "Source folder does not exist: $SOURCE"
        echo "Error: Source folder does not exist"
        return 1
    fi

    DATE=$(date +%Y-%m-%d_%H_%M_%S)
    BACKUP_NAME="backup_$DATE"

    BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    BACKUP_META="$BACKUP_DIR/$BACKUP_NAME.meta"

    # Prevent overwriting an existing backup
    if [ -e "$BACKUP_FILE" ] || [ -e "$BACKUP_META" ]; then
        log_message "ERROR" "Backup already exists: $BACKUP_NAME"
        echo "Error: Backup already exists!"
        return 1
    fi

    # Create backup
    if tar -czf "$BACKUP_FILE" \
        -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")" \
        2>&1 | tee -a "$LOG_FILE"; then

        # Verify backup integrity
        if tar -tzf "$BACKUP_FILE" > /dev/null \
            2> >(tee -a "$LOG_FILE"); then

            # Collect metadata
            CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
            BACKUP_SIZE=$(stat -c '%s bytes' "$BACKUP_FILE")

            # Save metadata
            if {
                printf 'Backup Name: %s\n' "$BACKUP_NAME"
                printf 'Source: %s\n' "$SOURCE"
                printf 'Created At: %s\n' "$CREATED_AT"
                printf 'Size: %s\n' "$BACKUP_SIZE"
                printf 'Verification: PASSED\n'
            } > "$BACKUP_META"; then

                log_message "SUCCESS" "Backup created and verified: $BACKUP_NAME"
                echo "Backup created and verified successfully!"
                apply_retention

            else
                log_message "WARNING" "Backup is valid but metadata could not be saved: $BACKUP_NAME"
                echo "Warning: Backup is valid, but metadata could not be saved."
            fi

        else
            STATUS=$?
            rm -f -- "$BACKUP_FILE"

            log_message "ERROR" "Backup verification failed! Exit Status: $STATUS"
            echo "Error: Backup verification failed! Invalid backup removed."
            return 1
        fi

    else
        STATUS=$?
        rm -f -- "$BACKUP_FILE"

        log_message "ERROR" "Backup creation failed! Exit Status: $STATUS"
        echo "Error: Backup creation failed! Check the log file for more details."
        return 1
    fi
}

show_backup()
{
    if ! compgen -G "$BACKUP_DIR/*.tar.gz" > /dev/null; then
        echo "No backups found"
        log_message "INFO" "No backups found"
        return 0
    fi

    echo "Available Backups:"

    for BACKUP_FILE in "$BACKUP_DIR"/*.tar.gz; do

        BACKUP_NAME=$(basename "$BACKUP_FILE" .tar.gz)
        BACKUP_META="$BACKUP_DIR/$BACKUP_NAME.meta"
        BACKUP_META="${BACKUP_FILE%.tar.gz}.meta"
        
        # Skip displaying metadata for old backups without a .meta file
        if [ ! -f "$BACKUP_META" ]; then
            continue
        fi
        # Display backup information
        echo "-----------------------------"

        if [ -f "$BACKUP_META" ]; then
            cat "$BACKUP_META"
        else
            echo "Backup Name: $BACKUP_NAME"
            echo "Metadata: Not available (old backup)"
            echo "Size: $(stat -c '%s bytes' "$BACKUP_FILE")"
        fi

    done

    log_message "INFO" "Backup list displayed"
}

restore_backup()
{
    echo "Enter backup name:"
    read -r BACKUP_NAME

    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]; then
        log_message "ERROR" "Backup not found: $BACKUP_NAME"
        echo "Error: Backup not found!"
        return 1
    fi

    echo "Enter destination folder:"
    read -r DESTINATION

    if [ ! -d "$DESTINATION" ]; then
        log_message "ERROR" "Destination folder does not exist: $DESTINATION"
        echo "Error: Destination folder does not exist!"
        return 1
    fi

    # Preview the contents of the backup before restoring
    echo "Backup Contents Preview:"
    echo "-----------------------------"

    if tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz"; then
        echo "-----------------------------"
    else
        STATUS=$?
        log_message "ERROR" "Restore preview failed! Exit Status: $STATUS"
        echo "Error: Cannot preview this backup!"
        return 1
    fi

    # Ask for confirmation before restoring
    echo "Do you want to restore this backup? (y/n)"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        log_message "INFO" "Restore cancelled by user"
        return 0
    fi

    if tar -xzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
        -C "$DESTINATION" 2>&1 | tee -a "$LOG_FILE"; then

        log_message "SUCCESS" "Restore completed: $BACKUP_NAME"
        echo "Restore successful!"

    else
        STATUS=${PIPESTATUS[0]}
        log_message "ERROR" "Restore failed! Exit Status: $STATUS"
        echo "Error: Restore failed! Check the log file for more details."
        return 1
    fi
}

schedule_backup()
{
    echo "Enter source folder path:"
    read -r SOURCE

    if [ ! -d "$SOURCE" ]; then
        echo "Error: Source folder does not exist!"
        log_message "ERROR" "Schedule failed: Invalid source folder: $SOURCE"
        return 1
    fi

    SOURCE="$(realpath "$SOURCE")"
    
    echo "Choose backup frequency:"
    echo "1. Daily"
    echo "2. Weekly"
    echo "3. Monthly"

    read -r FREQUENCY

    case "$FREQUENCY" in
    1)
        CRON_DAY="*"
        CRON_MONTH="*"
        CRON_WEEKDAY="*"
        ;;
    2)
        CRON_DAY="*"
        CRON_MONTH="*"
        CRON_WEEKDAY="0"
        ;;
    3)
        CRON_DAY="1"
        CRON_MONTH="*"
        CRON_WEEKDAY="*"
        ;;
    *)
        echo "Invalid frequency!"
        log_message "ERROR" "Invalid backup frequency"
        return 1
        ;;
    esac

    echo "Enter backup hour (0-23):"
    read -r HOUR

    echo "Enter backup minute (0-59):"
    read -r MINUTE

    if ! [[ "$HOUR" =~ ^[0-9]+$ && "$MINUTE" =~ ^[0-9]+$ ]]; then
    echo "Invalid time!"
    log_message "ERROR" "Invalid schedule time"
    return 1
    fi

    if (( 10#$HOUR > 23 || 10#$MINUTE > 59 )); then
    echo "Invalid time!"
    log_message "ERROR" "Invalid schedule time"
    return 1
    fi

    # Prepare cron command
    printf -v SOURCE_ESCAPED '%q' "$SOURCE"
    printf -v SCRIPT_ESCAPED '%q' "$SCRIPT_PATH"

    CRON_JOB="$MINUTE $HOUR $CRON_DAY $CRON_MONTH $CRON_WEEKDAY /bin/bash $SCRIPT_ESCAPED --auto-backup $SOURCE_ESCAPED # BACKUP_MANAGER_AUTO"

# Remove previous scheduled backup and add the new one
    if (
        crontab -l 2>/dev/null | grep -vF '# BACKUP_MANAGER_AUTO'
        printf '%s\n' "$CRON_JOB"
        ) | crontab -; then

        echo "Backup scheduled successfully!"
        log_message "SUCCESS" "Backup scheduled: $SOURCE at $HOUR:$MINUTE with frequency $FREQUENCY"

    else
        echo "Error: Failed to schedule backup!"
        log_message "ERROR" "Failed to add backup schedule"
        return 1
    fi
}

configure_retention()
{
    echo "How many backups do you want to keep?"
    read -r KEEP_COUNT

    if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]] || [ "$KEEP_COUNT" -lt 1 ]; then
        echo "Invalid number! Enter a number greater than 0."
        log_message "ERROR" "Invalid retention count"
        return 1
    fi

    if echo "$KEEP_COUNT" > "$RETENTION_FILE"; then
        echo "Retention configured successfully!"
        log_message "SUCCESS" "Retention configured: Keep last $KEEP_COUNT backups"
    else
        echo "Failed to save retention settings!"
        log_message "ERROR" "Failed to save retention settings"
        return 1
    fi
}

apply_retention()
{
    if [ ! -f "$RETENTION_FILE" ]; then
        return 0
    fi

    KEEP_COUNT=$(< "$RETENTION_FILE")

    if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]] || [ "$KEEP_COUNT" -lt 1 ]; then
        log_message "ERROR" "Invalid retention configuration"
        return 1
    fi

    mapfile -t BACKUPS < <(
        find "$BACKUP_DIR" -maxdepth 1 -type f -name 'backup_*.tar.gz' \
        -printf '%f\n' | sort -r
    )

    TOTAL_BACKUPS=${#BACKUPS[@]}

    if [ "$TOTAL_BACKUPS" -le "$KEEP_COUNT" ]; then
        return 0
    fi

    for (( i=KEEP_COUNT; i<TOTAL_BACKUPS; i++ )); do
        BACKUP_FILE="$BACKUP_DIR/${BACKUPS[$i]}"
        BACKUP_META="$BACKUP_DIR/${BACKUPS[$i]%.tar.gz}.meta"

        if rm -- "$BACKUP_FILE"; then
            rm -f -- "$BACKUP_META"
            log_message "INFO" "Old backup removed: ${BACKUPS[$i]}"
            echo "Removed old backup: ${BACKUPS[$i]}"
        else
            log_message "ERROR" "Failed to remove old backup: ${BACKUPS[$i]}"
        fi
    done
}

delete_backup()
{
    echo "Enter backup name:"
    read -r BACKUP_NAME

    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]; then
        log_message "ERROR" "Backup not found: $BACKUP_NAME"
        echo "Error: Backup not found!"
        return 1
    fi

    echo "Are you sure you want to delete $BACKUP_NAME? (y/n)"
    read -r CONFIRM

    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then

        if rm -- "$BACKUP_DIR/$BACKUP_NAME.tar.gz" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "SUCCESS" "Backup deleted: $BACKUP_NAME"
            echo "Backup deleted successfully!"

        else
            STATUS=${PIPESTATUS[0]}
            log_message "ERROR" "Delete failed! Exit Status: $STATUS"
            echo "Error: Delete failed! Check the log file for more details."
            return 1
        fi

    else
        log_message "INFO" "Delete cancelled: $BACKUP_NAME"
        echo "Delete cancelled."
    fi
}

if [ "${1:-}" = "--auto-backup" ]; then
    if [ -z "${2:-}" ]; then
        echo "Error: Source folder is missing!"
        exit 1
    fi

    create_backup "$2"
    exit $?
fi

while true
do
    echo
    echo "========================================="
    echo "       Automated Backup Management       "
    echo "========================================="
    echo "1. Create Backup"
    echo "2. Show Backups"
    echo "3. Restore Backup"
    echo "4. Delete Backup"
    echo "5. Schedule Auto Backup"
    echo "6. Configure Backup Retention"
    echo "7. Exit"
    echo "========================================="

    read -r -p "Enter your choice: " CHOICE

    case "$CHOICE" in
        1)
            create_backup
            ;;
        2)
            show_backup
            ;;
        3)
            restore_backup
            ;;
        4)
            delete_backup
            ;;
        5)
            schedule_backup
            ;;
        6)
            configure_retention
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice, enter a number between 1 and 7"
            ;;
    esac
done
