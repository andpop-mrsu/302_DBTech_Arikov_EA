PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

-- Временная таблица хранит данные фильмов и их новые идентификаторы.
CREATE TEMP TABLE added_movies (
    title TEXT PRIMARY KEY,
    year INTEGER NOT NULL,
    genre TEXT NOT NULL,
    rating REAL NOT NULL,
    review TEXT NOT NULL,
    movie_id INTEGER
) WITHOUT ROWID;

INSERT INTO added_movies (title, year, genre, rating, review)
VALUES
    ('Flow', 2024, 'Animation', 5, 'История держит внимание без единой реплики.'),
    ('Dune: Part Two', 2024, 'Sci-Fi', 4.5, 'Звук и пейзажи подчёркивают масштаб происходящего.'),
    ('Conclave', 2024, 'Thriller', 4, 'Напряжение растёт с каждым раундом голосования.');

-- Дату регистрации SQLite подставляет из системного времени.
INSERT OR ROLLBACK INTO users (first_name, last_name, email, gender, occupation_id)
VALUES
    ('Эвинир', 'Ариков', 'evinir.arikov@example.com', 'male',
     (SELECT id FROM occupations WHERE name = 'student')),
    ('Амир', 'Али', 'amir.ali@example.com', 'male',
     (SELECT id FROM occupations WHERE name = 'student')),
    ('Станислав', 'Батюков', 'stanislav.batyukov@example.com', 'male',
     (SELECT id FROM occupations WHERE name = 'student')),
    ('Олеся', 'Бутяйкина', 'olesya.butyaikina@example.com', 'female',
     (SELECT id FROM occupations WHERE name = 'student')),
    ('Дмитрий', 'Верочкин', 'dmitry.verochkin@example.com', 'male',
     (SELECT id FROM occupations WHERE name = 'student'));

-- last_insert_rowid() возвращает ID фильма, только что добавленного этим соединением.
INSERT INTO movies (title, year)
SELECT title, year FROM added_movies WHERE title = 'Flow';
UPDATE added_movies SET movie_id = last_insert_rowid() WHERE title = 'Flow';

INSERT INTO movies (title, year)
SELECT title, year FROM added_movies WHERE title = 'Dune: Part Two';
UPDATE added_movies SET movie_id = last_insert_rowid() WHERE title = 'Dune: Part Two';

INSERT INTO movies (title, year)
SELECT title, year FROM added_movies WHERE title = 'Conclave';
UPDATE added_movies SET movie_id = last_insert_rowid() WHERE title = 'Conclave';

INSERT INTO movie_genres (movie_id, genre_id)
SELECT movie_id, (SELECT id FROM genres WHERE name = added_movies.genre)
FROM added_movies;

INSERT INTO ratings (user_id, movie_id, rating)
SELECT (SELECT id FROM users WHERE email = 'evinir.arikov@example.com'), movie_id, rating
FROM added_movies;

INSERT INTO tags (user_id, movie_id, tag)
SELECT (SELECT id FROM users WHERE email = 'evinir.arikov@example.com'), movie_id, review
FROM added_movies;

DROP TABLE added_movies;
COMMIT;
