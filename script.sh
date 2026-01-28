#!/bin/bash
set -euo pipefail

[[ -f ./.env ]] && source .env

source lib.sh || {
    echo "Error: Support lib for script was not found" >&2
    exit 1
}

BACKUP=0
RESTORE=0
BACKUP_DIR=${BACKUP_DIR:-"./backup"}
RESTORE_FILE=${RESTORE_FILE:-$(get_recent_backup)}

while (($#)); do
    case $1 in
    --backup) BACKUP=1 ;;
    --restore) RESTORE=1 ;;
    --help)
        get_help
        exit 0
        ;;
    --backup-dir)
        BACKUP_DIR="$2"
        shift 1
        ;;
    -u | --user)
        DB_USER="$2"
        shift 1
        ;;
    -d | --database-name)
        DB_NAME="$2"
        shift 1
        ;;
    -c | --container)
        CONTAINER="$2"
        shift 1
        ;;
    -f | --restore-file)
        RESTORE_FILE="$2"
        shift 1
        ;;
    *)
        echo "Unknown option: $1. Use --help for more information."
        exit 1
        ;;
    esac
    shift 1
done

if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo "Error: Container named '$CONTAINER' was not found." >&2
    exit 1
fi

((BACKUP && RESTORE)) && {
    echo "Error: --backup and --restore can not be used together" >&2
    exit 1
}

((BACKUP)) && {
    echo "Initializing backup on $CONTAINER..."
    if create_backup_snapshot; then
        echo "Backup successfully, check $BACKUP_DIR"
        exit 0
    fi

    echo "Failed to backup." >&2
    exit 1
}

((RESTORE)) && {
    echo "Starting restoration on $CONTAINER..."
    if restore_selected_backup; then
        echo "Restore $RESTORE_FILE successfully for $DB_NAME on $CONTAINER."
        exit 0
    fi

    echo "Failed to restore $RESTORE_FILE for $DB_NAME on $CONTAINER."
    exit 1
}
