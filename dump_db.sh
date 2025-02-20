docker exec -t hotel-reservations-db pg_dump -U lucas -d posgres | gzip >database/dump.sql.gz
