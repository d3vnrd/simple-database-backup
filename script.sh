#!/usr/bin/env bash

# required flags
BACKUP=false
RESTORE=false
CONTAINER=""
DB_USER=""
DB_NAME=""

# optional default flags
BACKUP_DIR=${BACKUP_DIR:-"./backup"}
RESTORE_FILE=${RESTORE_FILE:-"$BACKUP_DIR/$(
    # Simple find command to look for the most recent backup file
    # -type f tells find to look for file not directory;
    # -name for exact name match up;
    # -exec tells find which command to run on matched result, in this case
    # ls -t1 {} + just sort its order in ascending order
    # | head -n 1 pipe the matched output to head to display the single top case
    find "$BACKUP_DIR" -type f \
        -name "${DB_NAME}_backup_*.sql" \
        -exec ls -t1 {} + | head -n 1
)"}

help() {
    # EOF stand for End-of-File, just a common name convention for a delimiter
    # which allow user to pass multi-line strings, pretty much like """ in python.
    # The differences between EOF and 'EOF' is that EOF allow shell expansion while
    # 'EOF' does not, so $USER does not expand to whatever value it holds.
    cat <<'EOF'
NAME
    ./script.sh - backup and restore a PostgreSQL database running in Docker

SYNOPSIS
    ./script.sh [--backup | --restore] [options]

REQUIRED OPTIONS
    -c, --container CONTAINER
        Name or ID of the Docker container running PostgreSQL.

    -U, --user DB_USER
        PostgreSQL user used for backup or restore.

    -d, --database-name DB_NAME
        Name of the PostgreSQL database.

MODES
    --backup
        Create a new backup snapshot.

    --restore
        Restore the database from a backup sql file.

OPTIONAL OPTIONS
    -f, --restore-file FILE
        SQL file to restore from.
        Defaults to the most recent backup in BACKUP_DIR.

    --backup-dir BACKUP_DIR
        Directory used to store backups.
        Default: ./backup

FILES
    BACKUP_DIR/DB_NAME_backup_YYYYMMDD_HHMMSS.sql
        Backup file naming format.

EXIT STATUS
    0   Success.
    1   Failure due to invalid arguments, missing parameters,
        Docker errors, or PostgreSQL errors.

EXAMPLES
    Create a backup:
        ./script.sh --backup -c pg_container -U postgres -d mydb

    Restore the latest backup:
        ./script.sh --restore -c pg_container -U postgres -d mydb

    Restore from a specific file:
        ./script.sh --restore -c pg_container -U postgres -d mydb \
            -f ./backup/mydb_backup_20260120_143211.sql

SEE ALSO
    docker(1), pg_dump(1), psql(1)
EOF
}

create_backup_snapshot() {
    mkdir -p "$BACKUP_DIR" # create backup dir if not existed, skip error raise
    docker exec "$CONTAINER" \
        pg_dump -c -U "$DB_USER" "$DB_NAME" \
        >"${BACKUP_DIR}/${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"

    # return status of function by default is the exit status of the most recent executed command
}

restore_selected_backup() {
    [ -f "${RESTORE_FILE}" ] &&
        docker exec -i "$CONTAINER" \
            psql -U "$DB_USER" "$DB_NAME" <"${RESTORE_FILE}" # direct the backup file as input in backup command

    # return status of function by default is the exit status of the most recent executed command
}

while (($#)); do
    # (()) is arithmetric evaluation in which evaluates
    # the current input args number '$#' if it is non-zero.
    # The return status will be 0 if the expression is empty,
    # otherwise, it returns 1.

    case $1 in
    --backup)
        BACKUP=true
        shift 1 # continue with the next flag
        ;;
    --restore)
        RESTORE=true
        shift 1
        ;;
    --help)
        help
        exit 0
        ;;
    --backup-dir)
        BACKUP_DIR="$2"
        shift 2
        ;;
    -U | --user)
        DB_USER="$2"
        shift 2
        ;;
    -d | --database-name)
        DB_NAME="$2"
        shift 2
        ;;
    -c | --container)
        CONTAINER="$2"
        shift 2
        ;;
    -f | --restore-file)
        RESTORE_FILE="$2"
        shift 2
        ;;
    *)
        echo "Unknown option: $1. Use --help for more information."
        exit 1
        ;;
    esac
done

if $BACKUP && $RESTORE; then
    echo "ERROR: --backup and --restore can not be in the same command."
    exit 1
fi

for var in CONTAINER DB_NAME DB_USER; do
    # conditional expression with compound command
    [ -z "${!var}" ] && { # ! allow evaluate value of passing variable not its name
        echo "ERROR: Missing required parameter ${var}."
        exit 1
    }
done

if [ "$BACKUP" = true ]; then
    create_backup_snapshot || {
        echo "ERROR: failed to backup current database."
        exit 1
    } # if cmd exit status is non-zero call echo and exit
fi

if [ "$RESTORE" = true ]; then
    restore_selected_backup || {
        echo "ERROR: failed to restore selected backup."
        exit 1
    } # if cmd exit status is non-zero call echo and exit
fi
