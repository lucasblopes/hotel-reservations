#!/bin/bash

# PostgreSQL Restore Script
# Usage: ./restore_db.sh backup_file_name

# Check if backup file was specified
if [ -z "$1" ]; then
    echo "Error: No backup file specified"
    echo "Usage: $0 backup_file_name"
    exit 1
fi

BACKUP_FILE=$1

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Validate backup file (check if it's a valid PostgreSQL dump)
if grep -q "pg_dump: error" "$BACKUP_FILE"; then
    echo "Error: The backup file contains error messages, not SQL data:"
    head -n 5 "$BACKUP_FILE"
    echo "Please create a valid backup before attempting to restore."
    exit 1
fi

# Check if file appears to be a PostgreSQL dump
if ! grep -q "PostgreSQL database dump" "$BACKUP_FILE" && ! grep -q "SET statement_timeout = 0;" "$BACKUP_FILE" && ! grep -q "CREATE TABLE" "$BACKUP_FILE"; then
    echo "Warning: This doesn't appear to be a valid PostgreSQL dump file."
    echo "First few lines of the file:"
    head -n 5 "$BACKUP_FILE"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
fi

# PostgreSQL connection parameters from Docker
DB_NAME="bookings"
DB_USER="lucas"
DB_PASS="admin"
DB_HOST="localhost"
DB_PORT="5432"
CONTAINER_NAME="hotel-reservations-db"

# Confirm restore
echo "WARNING: This will overwrite the current database '$DB_NAME'"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Create a temporary file for error output
ERROR_LOG=$(mktemp)

# Check if using Docker container
if [ -n "$CONTAINER_NAME" ] && docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
    echo "Using Docker container: $CONTAINER_NAME"
    echo "Restoring database: $DB_NAME from file: $BACKUP_FILE"

    # Create temporary copy inside container
    docker cp $BACKUP_FILE $CONTAINER_NAME:/tmp/backup.sql

    # Restore database (with error capture)
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>$ERROR_LOG
    if [ $? -ne 0 ]; then
        echo "Error dropping/recreating schema:"
        cat $ERROR_LOG
        exit 1
    fi

    # Execute the SQL dump file
    docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -f /tmp/backup.sql 2>$ERROR_LOG
    RESTORE_RESULT=$?

    # Remove temporary file
    docker exec $CONTAINER_NAME rm /tmp/backup.sql
else
    # Restore using local psql
    echo "Restoring database: $DB_NAME from file: $BACKUP_FILE"
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>$ERROR_LOG
    if [ $? -ne 0 ]; then
        echo "Error dropping/recreating schema:"
        cat $ERROR_LOG
        exit 1
    fi

    PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $BACKUP_FILE 2>$ERROR_LOG
    RESTORE_RESULT=$?
fi

# Check if restore was successful
if [ $RESTORE_RESULT -eq 0 ] && [ ! -s "$ERROR_LOG" ]; then
    echo "Restore completed successfully!"
else
    echo "Restore failed with errors:"
    cat "$ERROR_LOG"
    echo "Please check that your backup file contains valid SQL statements."
    exit 1
fi

# Clean up error log
rm -f "$ERROR_LOG"
