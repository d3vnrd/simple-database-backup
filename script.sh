#!/usr/bin/env bash

# default configs
DB_USER="tester"
DB_NAME="testdb"
CONTAINER_NAME="database"
BACKUP_DIR="./backup"
FORMAT="+%Y%m%d_%H%M%S"

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

create_backup_snapshot() {
    local time
    time=$(date $FORMAT)
    local output="${BACKUP_DIR}/${DB_NAME}_backup_${time}.sql"

    if docker exec "$CONTAINER_NAME" \
        pg_dump -c -U "$DB_USER" "$DB_NAME" >"$output"; then
        return 0
    else
        rm -f "$output" # remove file if unable to run command
        return 1
    fi
}

restore_selected_backup() {
    # get user input on which file to backup if not provided return with the most recent one
    local backup_file=""
    local input="${1:-$(
        find $BACKUP_DIR -type f \
            -name "${DB_NAME}_backup_*.sql" \
            -exec ls -t1 {} + | head -n 1
    )}"

    if [ -f "$input" ]; then
        backup_file="$input"
    elif [ -f "${BACKUP_DIR}/${input}" ]; then
        backup_file="${BACKUP_DIR}/${input}"
    else
        echo "Backup file for ${DB_NAME} not found: $input"
        return 1
    fi

    docker exec -i "$CONTAINER_NAME" \
        psql -U "$DB_USER" "$DB_NAME" <"$backup_file"
}

if [ $# -eq 1 ] || [ $# -eq 2 ]; then # accept only 1 or 2 parameter inputs
    case $1 in
    -b | --backup)
        create_backup_dir      # create backup dir if not existed
        create_backup_snapshot # create snapshot
        exit 0
        ;;
    -r | --restore)
        restore_selected_backup "$2" # restore backup with optional selected one
        exit 0
        ;;
    *)
        echo "Unknown args: $1"
        exit 1
        ;;
    esac
else
    echo "Missing or exceeding required args."
    exit 1
fi
