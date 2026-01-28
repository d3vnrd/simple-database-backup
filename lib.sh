[[ "${BASH_SOURCE[0]}" == "$0" ]] && {
    echo "Error: This file is not meant to be executed."
    exit 1
}

create_backup_snapshot() {
    mkdir -p "$BACKUP_DIR" # create backup dir if not existed, skip error raise
    docker exec "$CONTAINER" \
        pg_dump -c -U "$DB_USER" "$DB_NAME" \
        >"${BACKUP_DIR}/${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
}

restore_selected_backup() {
    [[ -f $RESTORE_FILE ]] &&
        docker exec -i "$CONTAINER" \
            psql -U "$DB_USER" "$DB_NAME" \
            <"${RESTORE_FILE}" # direct the backup file as input in restore command
}

get_recent_backup() {
    find "$BACKUP_DIR" -type f \
        -name "${DB_NAME}_backup_*.sql" \
        -exec ls -t1 {} + | head -n 1

    # A simple find command to look for the most recent backup file
    # -type f tells find to look for file not directory;
    # -name for exact name match up;
    # -exec tells find to run consequent command on matched result, in this case
    # ls -t1 {} + just sort its order in ascending order
    # | head -n 1 pipe the matched output to head to display the single top case
}

get_help() {
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

    -u, --user DB_USER
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
