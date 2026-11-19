#!/bin/bash
# Runs once, on the first start of an empty Postgres data volume.
# Creates one database and one owner role per service.
set -euo pipefail

create_service_db() {
  local db="$1" role="$2" password="$3"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
       -v db="$db" -v role="$role" -v pw="$password" <<'EOSQL'
CREATE ROLE :"role" LOGIN PASSWORD :'pw';
CREATE DATABASE :"db" OWNER :"role";
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
EOSQL
}

create_service_db identity_db   identity_user   "$IDENTITY_DB_PASSWORD"
create_service_db assessment_db assessment_user "$ASSESSMENT_DB_PASSWORD"
create_service_db exam_db       exam_user       "$EXAM_DB_PASSWORD"