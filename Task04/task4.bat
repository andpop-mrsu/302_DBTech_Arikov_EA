#!/bin/bash
set -e

# В Git Bash на Windows переключаем консоль на UTF-8; в Linux chcp отсутствует.
if command -v chcp >/dev/null 2>&1; then
    chcp 65001
fi

cd -- "$(dirname -- "$0")"

sqlite3 movies_rating.db < db_init.sql

echo "1. Все пары пользователей, оценивших один и тот же фильм (первые 100 пар):"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT DISTINCT
       u1.name AS user_1,
       u2.name AS user_2,
       m.title AS film
FROM ratings AS r1
JOIN ratings AS r2
  ON r2.movie_id = r1.movie_id
 AND r2.user_id > r1.user_id
JOIN users AS u1 ON u1.id = r1.user_id
JOIN users AS u2 ON u2.id = r2.user_id
JOIN movies AS m ON m.id = r1.movie_id
ORDER BY m.title, u1.name, u2.name
LIMIT 100;
"
echo " "

echo "2. Десять самых свежих оценок от разных пользователей:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH ranked_ratings AS (
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY r.user_id
               ORDER BY r.timestamp DESC, r.id DESC
           ) AS row_number
    FROM ratings AS r
)
SELECT m.title AS film,
       u.name AS user_name,
       rr.rating,
       date(rr.timestamp, 'unixepoch') AS review_date
FROM ranked_ratings AS rr
JOIN movies AS m ON m.id = rr.movie_id
JOIN users AS u ON u.id = rr.user_id
WHERE rr.row_number = 1
ORDER BY rr.timestamp DESC, rr.id DESC
LIMIT 10;
"
echo " "

echo "3. Фильмы с максимальным и минимальным средним рейтингом:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH movie_ratings AS (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS average_rating
    FROM movies AS m
    JOIN ratings AS r ON r.movie_id = m.id
    GROUP BY m.id, m.title, m.year
),
rating_limits AS (
    SELECT MAX(average_rating) AS maximum_rating,
           MIN(average_rating) AS minimum_rating
    FROM movie_ratings
)
SELECT mr.title AS film,
       mr.year AS release_year,
       ROUND(mr.average_rating, 2) AS average_rating,
       CASE
           WHEN mr.average_rating = rl.maximum_rating THEN 'Да'
           ELSE 'Нет'
       END AS [Рекомендуем]
FROM movie_ratings AS mr
CROSS JOIN rating_limits AS rl
WHERE mr.average_rating IN (rl.maximum_rating, rl.minimum_rating)
ORDER BY mr.year, mr.title;
"
echo " "

echo "4. Количество и средняя оценка от пользователей-женщин за 2010–2012 годы:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT COUNT(*) AS rating_count,
       ROUND(AVG(r.rating), 2) AS average_rating
FROM ratings AS r
JOIN users AS u ON u.id = r.user_id
WHERE u.gender = 'female'
  AND date(r.timestamp, 'unixepoch') BETWEEN '2010-01-01' AND '2012-12-31';
"
echo " "

echo "5. Фильмы со средней оценкой и местом в рейтинге (первые 20 фильмов):"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH movie_ratings AS (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS average_rating
    FROM movies AS m
    JOIN ratings AS r ON r.movie_id = m.id
    GROUP BY m.id, m.title, m.year
),
ranked_movies AS (
    SELECT title,
           year,
           average_rating,
           RANK() OVER (ORDER BY average_rating DESC) AS rating_place
    FROM movie_ratings
)
SELECT title AS film,
       year AS release_year,
       ROUND(average_rating, 2) AS average_rating,
       rating_place
FROM ranked_movies
ORDER BY year, title
LIMIT 20;
"
echo " "

echo "6. Десять последних зарегистрированных пользователей в формате «Фамилия Имя|Дата регистрации»:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT substr(name, instr(name, ' ') + 1) || ' ' ||
       substr(name, 1, instr(name, ' ') - 1) || '|' ||
       register_date AS [Фамилия Имя|Дата регистрации]
FROM users
ORDER BY date(register_date) DESC, id DESC
LIMIT 10;
"
echo " "

echo "7. Таблица умножения для чисел от 1 до 10 с помощью рекурсивного CTE:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE multiplication(first_number, second_number) AS (
    SELECT 1, 1
    UNION ALL
    SELECT CASE
               WHEN second_number = 10 THEN first_number + 1
               ELSE first_number
           END,
           CASE
               WHEN second_number = 10 THEN 1
               ELSE second_number + 1
           END
    FROM multiplication
    WHERE NOT (first_number = 10 AND second_number = 10)
)
SELECT first_number || 'x' || second_number || '=' ||
       (first_number * second_number) AS multiplication_table
FROM multiplication;
"
echo " "

echo "8. Все жанры фильмов из таблицы movies, каждый жанр в отдельной строке:"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(genre, remainder) AS (
    SELECT '', genres || '|'
    FROM movies
    UNION ALL
    SELECT substr(remainder, 1, instr(remainder, '|') - 1),
           substr(remainder, instr(remainder, '|') + 1)
    FROM split_genres
    WHERE remainder <> ''
)
SELECT DISTINCT genre
FROM split_genres
WHERE genre <> ''
ORDER BY genre;
"
echo " "
