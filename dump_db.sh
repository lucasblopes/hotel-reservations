docker exec -t hotel-reservations-db pg_dump -U lucas -d postgres | gzip >database/dump.sql.gz
