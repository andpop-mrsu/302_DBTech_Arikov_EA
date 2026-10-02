#!/bin/bash
python3 "$(dirname "$0")/make_db_init.py" || exit 1
sqlite3 "$(dirname "$0")/movies_rating.db" < "$(dirname "$0")/db_init.sql"
