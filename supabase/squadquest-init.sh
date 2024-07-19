#!/bin/bash

set -eu

cd "$(dirname "$0")"

ordered_tables=(
    profiles
    topics
    instances
)

PSQL='docker compose exec -T db psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres'

# execute _common first
echo
echo "> running: _common.sql"
$PSQL <_common.sql

# execute ordered tables next
for table in "${ordered_tables[@]}"; do
    echo
    echo "> running: tables/$table.sql"
    $PSQL <"tables/$table.sql"
done

# execute all other tables
for sql in tables/*.sql; do
    for ordered_table in "${ordered_tables[@]}"; do
        if [[ $sql == "tables/$ordered_table.sql" ]]; then
            continue 2
        fi
    done

    echo
    echo "> running: $sql"
    $PSQL <"$sql"
done

# execute all policies
for sql in policies/*.sql; do
    echo
    echo "> running: $sql"
    $PSQL <"$sql"
done
