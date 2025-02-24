#!/bin/bash

# PostgreSQL Backup Script
# Usage: ./dump_db.sh [backup_file_name]

# Default backup file name with timestamp
DEFAULT_BACKUP_FILE="postgres_backup_$(date +%Y%m%d_%H%M%S).sql"
BACKUP_FILE=${1:-$DEFAULT_BACKUP_FILE}

# PostgreSQL connection parameters from Docker
DB_NAME="postgres" # Correct spelling - not "posgres"
DB_USER="lucas"
DB_PASS="admin"
DB_HOST="localhost"
DB_PORT="5432"
CONTAINER_NAME="hotel-reservations-db"

# Create a temporary file for error output
ERROR_LOG=$(mktemp)

# Print configuration for verification
echo "Backup Configuration:"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Container: $CONTAINER_NAME"
echo "Output file: $BACKUP_FILE"

# Check if using Docker container
if [ -n "$CONTAINER_NAME" ] && docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
    echo "Using Docker container: $CONTAINER_NAME"

    # Verify database exists before attempting backup
    DB_EXISTS=$(docker exec $CONTAINER_NAME psql -U $DB_USER -lqt | grep -c "\b$DB_NAME\b")

    if [ "$DB_EXISTS" -eq "0" ]; then
        echo "Error: Database '$DB_NAME' does not exist in container!"
        echo "Available databases:"
        docker exec $CONTAINER_NAME psql -U $DB_USER -l
        exit 1
    fi

    # Backup using Docker with error redirection
    echo "Backing up database: $DB_NAME to file: $BACKUP_FILE"
    docker exec $CONTAINER_NAME pg_dump -U $DB_USER -d $DB_NAME >$BACKUP_FILE 2>$ERROR_LOG
else
    # Verify database exists
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | grep -c "\b$DB_NAME\b" >/dev/null

    if [ $? -ne 0 ]; then
        echo "Error: Unable to connect to database or database '$DB_NAME' does not exist!"
        echo "Please check your connection parameters."
        exit 1
    fi

    # Backup using local pg_dump
    echo "Backing up database: $DB_NAME to file: $BACKUP_FILE"
    PGPASSWORD=$DB_PASS pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME >$BACKUP_FILE 2>$ERROR_LOG
fi

# Check if backup was successful
if [ $? -eq 0 ] && [ ! -s "$ERROR_LOG" ]; then
    # Verify file contains SQL data
    if grep -q "PostgreSQL database dump" "$BACKUP_FILE" || grep -q "SET statement_timeout = 0;" "$BACKUP_FILE" || grep -q "CREATE TABLE" "$BACKUP_FILE"; then
        echo "Backup completed successfully: $BACKUP_FILE"
        echo "File size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        echo "Warning: Backup completed but file might not contain valid SQL data."
        echo "Please check the file contents:"
        head -n 10 "$BACKUP_FILE"
    fi
else
    echo "Backup failed! Error output:"
    cat "$ERROR_LOG"
    echo "Please check your database connection parameters."
    rm -f "$BACKUP_FILE" # Remove potentially incomplete backup file
    exit 1
fi

# Clean up error log
rm -f "$ERROR_LOG"
