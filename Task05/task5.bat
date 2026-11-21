#!/bin/bash
set -e

# На Windows скрипт запускается через Git Bash.
if command -v chcp.com >/dev/null 2>&1; then
    chcp.com 65001
fi

cd -- "$(dirname -- "$0")"
sqlite3 movies_rating.db -batch -bail < db_init.sql

# Общий CTE для запросов 2–4. Маркер отсутствия жанра пропускаем.
genre_cte="
WITH RECURSIVE split_genres(movie_id, genre, remainder) AS (
    SELECT id, '', genres || '|'
    FROM movies
    WHERE genres <> '(no genres listed)'
    UNION ALL
    SELECT movie_id,
           substr(remainder, 1, instr(remainder, '|') - 1),
           substr(remainder, instr(remainder, '|') + 1)
    FROM split_genres
    WHERE remainder <> ''
),
movie_genres AS (
    SELECT DISTINCT movie_id, genre
    FROM split_genres
    WHERE genre <> ''
)
"

echo "1. Десять фильмов с наивысшим средним рейтингом и их ранги"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo -nullvalue NULL "
WITH movie_ratings AS (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating
    FROM movies AS m
    LEFT JOIN ratings AS r ON r.movie_id = m.id
    GROUP BY m.id, m.title, m.year
),
ranked_movies AS (
    SELECT id, title, year, avg_rating,
           RANK() OVER (ORDER BY avg_rating DESC) AS rank_by_avg_rating
    FROM movie_ratings
    WHERE avg_rating IS NOT NULL
)
SELECT title, year, avg_rating, rank_by_avg_rating
FROM ranked_movies
ORDER BY rank_by_avg_rating, id
LIMIT 10;
"
echo " "

echo "2. Средний рейтинг фильмов по жанрам и ранг каждого жанра"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo -nullvalue NULL "${genre_cte},
movie_ratings AS (
    SELECT movie_id, AVG(rating) AS avg_rating
    FROM ratings
    GROUP BY movie_id
),
genre_ratings AS (
    SELECT mg.genre, AVG(mr.avg_rating) AS avg_rating
    FROM movie_genres AS mg
    LEFT JOIN movie_ratings AS mr ON mr.movie_id = mg.movie_id
    GROUP BY mg.genre
)
SELECT genre, avg_rating,
       RANK() OVER (ORDER BY avg_rating DESC) AS rank_by_avg_rating
FROM genre_ratings
ORDER BY rank_by_avg_rating, genre;
"
echo " "

echo "3. Количество фильмов в каждом жанре"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo "${genre_cte}
SELECT genre, COUNT(*) AS movie_count
FROM movie_genres
GROUP BY genre
ORDER BY movie_count DESC, genre;
"
echo " "

echo "4. Количество тегов по жанрам и доля от всех записей таблицы tags, в процентах"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo -nullvalue NULL "${genre_cte}
SELECT mg.genre, COUNT(t.id) AS tag_count,
       ROUND(100.0 * COUNT(t.id) / NULLIF((SELECT COUNT(*) FROM tags), 0), 2) AS tag_share
FROM movie_genres AS mg
LEFT JOIN tags AS t ON t.movie_id = mg.movie_id
GROUP BY mg.genre
ORDER BY tag_count DESC, mg.genre;
"
echo " "

echo "5. Десять пользователей с наибольшим числом оценок, их средние оценки и даты первой и последней оценки"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo -nullvalue NULL "
SELECT u.id AS user_id,
       COUNT(r.id) AS rating_count,
       AVG(r.rating) AS avg_rating,
       date(MIN(r.timestamp), 'unixepoch') AS first_rating_date,
       date(MAX(r.timestamp), 'unixepoch') AS last_rating_date
FROM users AS u
LEFT JOIN ratings AS r ON r.user_id = u.id
GROUP BY u.id
ORDER BY rating_count DESC, user_id
LIMIT 10;
"
echo " "

echo "6. Число оценок и тегов каждого пользователя и его категория поведения"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo "
WITH rating_counts AS (
    SELECT user_id, COUNT(*) AS rating_count
    FROM ratings
    GROUP BY user_id
),
tag_counts AS (
    SELECT user_id, COUNT(*) AS tag_count
    FROM tags
    GROUP BY user_id
),
user_activity AS (
    SELECT u.id AS user_id,
           COALESCE(r.rating_count, 0) AS rating_count,
           COALESCE(t.tag_count, 0) AS tag_count
    FROM users AS u
    LEFT JOIN rating_counts AS r ON r.user_id = u.id
    LEFT JOIN tag_counts AS t ON t.user_id = u.id
)
SELECT user_id, rating_count, tag_count,
       CASE
           WHEN tag_count > rating_count THEN 'Комментаторы'
           WHEN rating_count > tag_count THEN 'Оценщики'
           WHEN rating_count >= 10 AND tag_count >= 10 THEN 'Активные'
           WHEN rating_count < 5 AND tag_count < 5 THEN 'Пассивные'
           ELSE 'Без категории'
       END AS behavior_category
FROM user_activity
ORDER BY user_id;
"
echo " "

echo "7. Последний оценённый фильм каждого пользователя и время оценки"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -batch -bail -box -echo -nullvalue NULL "
WITH ranked_ratings AS (
    SELECT user_id, movie_id, timestamp,
           ROW_NUMBER() OVER (
               PARTITION BY user_id
               ORDER BY timestamp DESC, id DESC
           ) AS rating_position
    FROM ratings
)
SELECT u.id AS user_id, u.name,
       m.title AS last_rated_movie_title,
       r.timestamp AS last_rating_timestamp
FROM users AS u
LEFT JOIN ranked_ratings AS r ON r.user_id = u.id AND r.rating_position = 1
LEFT JOIN movies AS m ON m.id = r.movie_id
ORDER BY user_id;
"
