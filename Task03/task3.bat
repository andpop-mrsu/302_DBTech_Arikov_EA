#!/bin/bash
set -e

# В Git Bash на Windows переключаем консоль на UTF-8; в Linux chcp отсутствует.
if command -v chcp >/dev/null 2>&1; then
    chcp 65001
fi

sqlite3 movies_rating.db < db_init.sql

echo "1. Первые 10 фильмов, имеющих хотя бы одну оценку, по году выпуска и названию:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT m.title AS film, m.year AS release_year
FROM movies AS m
WHERE m.id IN (SELECT r.movie_id FROM ratings AS r)
ORDER BY m.year IS NULL, m.year, m.title
LIMIT 10;
"
echo " "

echo "2. Первые 5 пользователей с фамилией на букву A, по дате регистрации:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT u.name AS user_name, u.register_date
FROM users AS u
WHERE instr(u.name, ' ') > 0
  AND substr(u.name, instr(u.name, ' ') + 1, 1) = 'A'
ORDER BY u.register_date, u.id
LIMIT 5;
"
echo " "

echo "3. Первые 50 оценок: эксперт, фильм, год, оценка и дата в формате ГГГГ-ММ-ДД:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT u.name AS expert, m.title AS film, m.year AS release_year,
       r.rating, date(r.timestamp, 'unixepoch') AS rating_date
FROM ratings AS r
JOIN users AS u ON u.id = r.user_id
JOIN movies AS m ON m.id = r.movie_id
ORDER BY u.name, m.title, r.rating
LIMIT 50;
"
echo " "

echo "4. Первые 40 уникальных пар фильм — тег, по году, названию и тегу:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT DISTINCT m.title AS film, m.year AS release_year, t.tag
FROM movies AS m
JOIN tags AS t ON t.movie_id = m.id
ORDER BY m.year, m.title, t.tag
LIMIT 40;
"
echo " "

echo "5. Все фильмы самого позднего года выпуска в базе:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT m.title AS film, m.year AS release_year
FROM movies AS m
WHERE m.year = (SELECT MAX(year) FROM movies)
ORDER BY m.title;
"
echo " "

echo "6. Комедии после 2000 года с оценками мужчин не ниже 4.5:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT m.title AS film, m.year AS release_year,
       COUNT(*) AS matching_ratings
FROM movies AS m
JOIN ratings AS r ON r.movie_id = m.id
JOIN users AS u ON u.id = r.user_id
WHERE m.year > 2000
  AND instr('|' || m.genres || '|', '|Comedy|') > 0
  AND u.gender = 'male'
  AND r.rating >= 4.5
GROUP BY m.id, m.title, m.year
ORDER BY m.year, m.title;
"
echo " "

echo "7. Количество пользователей по профессиям:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT occupation, COUNT(*) AS user_count
FROM users
GROUP BY occupation
ORDER BY user_count DESC, occupation;
"
echo " "
echo "Самые распространённые и самые редкие профессии (включая совпадения):"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH occupation_counts AS (
    SELECT occupation, COUNT(*) AS user_count
    FROM users
    GROUP BY occupation
)
SELECT 'Самая распространённая' AS category, occupation, user_count
FROM occupation_counts
WHERE user_count = (SELECT MAX(user_count) FROM occupation_counts)
UNION ALL
SELECT 'Самая редкая' AS category, occupation, user_count
FROM occupation_counts
WHERE user_count = (SELECT MIN(user_count) FROM occupation_counts);
"
