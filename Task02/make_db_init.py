import csv
import re
from pathlib import Path

folder = Path(__file__).resolve().parent


def read_csv(filename):
    with (folder / filename).open(encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


movies = []
for row in read_csv("movies.csv"):
    title = row["title"]
    match = re.fullmatch(r"(.*) \((\d{4})\)", title)

    if match:
        title = match.group(1)
        year = int(match.group(2))
    else:
        year = None

    movies.append((int(row["movieId"]), title, year, row["genres"]))

ratings = [
    (
        int(row["userId"]),
        int(row["movieId"]),
        float(row["rating"]),
        int(row["timestamp"]),
    )
    for row in read_csv("ratings.csv")
]

tags = [
    (
        int(row["userId"]),
        int(row["movieId"]),
        row["tag"],
        int(row["timestamp"]),
    )
    for row in read_csv("tags.csv")
]

users = []
with (folder / "users.txt").open(encoding="utf-8-sig") as file:
    for line in file:
        if line.strip():
            fields = line.rstrip("\r\n").split("|", 5)
            users.append(
                (
                    int(fields[0]),
                    fields[1],
                    fields[2],
                    fields[3],
                    fields[4],
                    fields[5],
                )
            )


def max_length(rows, index):
    return max(1, max(len(str(row[index])) for row in rows))


def sql_value(value):
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return repr(value)
    return "'" + str(value).replace("'", "''") + "'"


statements = [
    "PRAGMA foreign_keys = OFF;",
    "BEGIN TRANSACTION;",
    "DROP TABLE IF EXISTS ratings;",
    "DROP TABLE IF EXISTS tags;",
    "DROP TABLE IF EXISTS movies;",
    "DROP TABLE IF EXISTS users;",
    f"""CREATE TABLE movies (
    id INTEGER PRIMARY KEY,
    title VARCHAR({max_length(movies, 1)}),
    year INTEGER,
    genres VARCHAR({max_length(movies, 3)})
);""",
    """CREATE TABLE ratings (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    movie_id INTEGER,
    rating REAL,
    timestamp INTEGER
);""",
    f"""CREATE TABLE tags (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    movie_id INTEGER,
    tag VARCHAR({max_length(tags, 2)}),
    timestamp INTEGER
);""",
    f"""CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name VARCHAR({max_length(users, 1)}),
    email VARCHAR({max_length(users, 2)}),
    gender VARCHAR({max_length(users, 3)}),
    register_date DATE,
    occupation VARCHAR({max_length(users, 5)})
);""",
]


def add_inserts(table, columns, rows):
    column_list = ", ".join(columns)
    for row in rows:
        values = ", ".join(sql_value(value) for value in row)
        statements.append(
            f"INSERT INTO {table} ({column_list}) VALUES ({values});"
        )


add_inserts("movies", ["id", "title", "year", "genres"], movies)
add_inserts(
    "ratings",
    ["user_id", "movie_id", "rating", "timestamp"],
    ratings,
)
add_inserts(
    "tags",
    ["user_id", "movie_id", "tag", "timestamp"],
    tags,
)
add_inserts(
    "users",
    ["id", "name", "email", "gender", "register_date", "occupation"],
    users,
)

statements.append("COMMIT;")
(folder / "db_init.sql").write_text(
    "\n".join(statements) + "\n",
    encoding="utf-8",
)

print(f"Создан db_init.sql: фильмов — {len(movies)}, оценок — {len(ratings)}, тегов — {len(tags)}, пользователей — {len(users)}")
