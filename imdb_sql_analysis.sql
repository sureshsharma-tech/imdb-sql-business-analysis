/*
========================================================
IMDb SQL Analysis Project
Author : Suresh Sharma
Project: IMDB SQL Business Analysis

Description:
This project analyzes the IMDb dataset using SQL.
It includes data quality analysis, actor and director
performance, production house analysis, genre insights,
and business-oriented SQL queries.

Tools Used:
- MySQL Workbench
- SQL

========================================================
*/

USE imdb;

-- =====================================================
-- Data Quality Assessment
-- Check NULL values in the Names table.
-- =====================================================

SELECT
    SUM(name IS NULL) AS name_nulls,
    SUM(height IS NULL) AS height_nulls,
    SUM(date_of_birth IS NULL) AS date_of_birth_nulls,
    SUM(known_for_movies IS NULL) AS known_for_movies_nulls
FROM names;



-- Director Performance Analysis

-- Identify the top three directors in the highest-rated genres

WITH top_genres AS (
    SELECT
        g.genre
    FROM genre g
    JOIN ratings r
        ON g.movie_id = r.movie_id
    WHERE r.avg_rating > 8
    GROUP BY g.genre
    ORDER BY COUNT(*) DESC
    LIMIT 3
)

SELECT
    n.name AS director_name,
    COUNT(*) AS movie_count
FROM director_mapping d
JOIN names n
    ON d.name_id = n.id
JOIN genre g
    ON d.movie_id = g.movie_id
JOIN ratings r
    ON d.movie_id = r.movie_id
WHERE r.avg_rating > 8
AND g.genre IN (SELECT genre FROM top_genres)
GROUP BY n.id, n.name
ORDER BY movie_count DESC
LIMIT 3;







-- Actor Performance Analysis

SELECT
    n.name AS actor_name,
    COUNT(*) AS movie_count
FROM role_mapping rm
JOIN names n
    ON rm.name_id = n.id
JOIN ratings r
    ON rm.movie_id = r.movie_id
WHERE rm.category = 'actor'
AND r.median_rating >= 8
GROUP BY n.id, n.name
ORDER BY movie_count DESC
LIMIT 2;



-- Production House Analysis

SELECT
    m.production_company,
    SUM(r.total_votes) AS vote_count,
    DENSE_RANK() OVER (ORDER BY SUM(r.total_votes) DESC) AS prod_comp_rank
FROM movie m
JOIN ratings r
    ON m.id = r.movie_id
WHERE m.production_company IS NOT NULL
GROUP BY m.production_company
ORDER BY vote_count DESC
LIMIT 3;



-- Indian Actor Analysis

SELECT
    n.name AS actor_name,
    SUM(r.total_votes) AS total_votes,
    COUNT(DISTINCT rm.movie_id) AS movie_count,
    ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 2) AS actor_avg_rating,
    DENSE_RANK() OVER (
        ORDER BY
        SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes) DESC,
        SUM(r.total_votes) DESC
    ) AS actor_rank
FROM role_mapping rm
JOIN names n
    ON rm.name_id = n.id
JOIN movie m
    ON rm.movie_id = m.id
JOIN ratings r
    ON rm.movie_id = r.movie_id
WHERE rm.category = 'actor'
AND m.country LIKE '%India%'
GROUP BY n.id, n.name
HAVING COUNT(DISTINCT rm.movie_id) >= 5
ORDER BY actor_rank
LIMIT 1;



-- Hindi Actress Analysis


SELECT
    n.name AS actress_name,
    SUM(r.total_votes) AS total_votes,
    COUNT(DISTINCT rm.movie_id) AS movie_count,
    ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 2) AS actress_avg_rating,
    DENSE_RANK() OVER (
        ORDER BY
        SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes) DESC,
        SUM(r.total_votes) DESC
    ) AS actress_rank
FROM role_mapping rm
JOIN names n
    ON rm.name_id = n.id
JOIN movie m
    ON rm.movie_id = m.id
JOIN ratings r
    ON rm.movie_id = r.movie_id
WHERE rm.category = 'actress'
AND m.country LIKE '%India%'
AND m.languages LIKE '%Hindi%'
GROUP BY n.id, n.name
HAVING COUNT(DISTINCT rm.movie_id) >= 3
ORDER BY actress_rank
LIMIT 5;


-- Thriller Movie Classification

SELECT
    m.title AS movie_name,
    CASE
        WHEN r.avg_rating > 8 THEN 'Superhit'
        WHEN r.avg_rating BETWEEN 7 AND 8 THEN 'Hit'
        WHEN r.avg_rating BETWEEN 5 AND 7 THEN 'One-time-watch'
        ELSE 'Flop'
    END AS movie_category
FROM movie m
JOIN ratings r
    ON m.id = r.movie_id
JOIN genre g
    ON m.id = g.movie_id
WHERE g.genre = 'Thriller'
AND r.total_votes >= 25000
ORDER BY r.avg_rating DESC;





-- Genre Duration Analysis

SELECT
    g.genre,
    ROUND(AVG(m.duration), 2) AS avg_duration,
    ROUND(
        SUM(AVG(m.duration)) OVER (
            ORDER BY g.genre
        ),
        2
    ) AS running_total_duration,
    ROUND(
        AVG(AVG(m.duration)) OVER (
            ORDER BY g.genre
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_duration
FROM genre g
JOIN movie m
    ON g.movie_id = m.id
GROUP BY g.genre
ORDER BY g.genre;



-- Highest Grossing Movies Analysis


WITH top_3_genres AS
(
    SELECT genre
    FROM genre
    GROUP BY genre
    ORDER BY COUNT(*) DESC
    LIMIT 3
),

ranked_movies AS
(
    SELECT
        g.genre,
        m.year,
        m.title AS movie_name,
        m.worlwide_gross_income,
        DENSE_RANK() OVER
        (
            PARTITION BY g.genre, m.year
            ORDER BY
            CAST(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(IFNULL(m.worlwide_gross_income,'0'),
                            'INR',''),
                        'USD',''),
                    '$',''),
                ',','')
            AS UNSIGNED) DESC
        ) AS movie_rank
    FROM movie m
    JOIN genre g
        ON m.id = g.movie_id
    WHERE g.genre IN
    (
        SELECT genre
        FROM top_3_genres
    )
    AND m.worlwide_gross_income IS NOT NULL
)

SELECT
    genre,
    year,
    movie_name,
    worlwide_gross_income,
    movie_rank
FROM ranked_movies
WHERE movie_rank <= 5
ORDER BY genre, year, movie_rank;





-- Multilingual Movies Analysis

SELECT 
    m.production_company,
    COUNT(m.id) AS movie_count,
    ROW_NUMBER() OVER (ORDER BY COUNT(m.id) DESC) AS prod_comp_rank
FROM movie m
INNER JOIN ratings r ON m.id = r.movie_id
WHERE r.median_rating >= 8 
  AND m.production_company IS NOT NULL 
  AND POSITION(',' IN m.languages) > 0 -- This filters for multilingual movies (containing commas)
GROUP BY m.production_company
LIMIT 2;


-- Drama Actress Analysis

SELECT
    n.name AS actress_name,
    SUM(r.total_votes) AS total_votes,
    COUNT(DISTINCT m.id) AS movie_count,
    ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 4) AS actress_avg_rating,
    ROW_NUMBER() OVER (
        ORDER BY
            ROUND(SUM(r.avg_rating * r.total_votes) / SUM(r.total_votes), 4) DESC,
            SUM(r.total_votes) DESC,
            n.name ASC
    ) AS actress_rank
FROM movie m
JOIN ratings r
    ON m.id = r.movie_id
JOIN role_mapping rm
    ON m.id = rm.movie_id
JOIN names n
    ON rm.name_id = n.id
JOIN genre g
    ON m.id = g.movie_id
WHERE rm.category = 'actress'
  AND g.genre = 'Drama'
  AND r.avg_rating > 8
GROUP BY n.id, n.name
ORDER BY
    actress_avg_rating DESC,
    total_votes DESC,
    actress_name ASC
LIMIT 3;



-- Director Performance Dashboard

WITH movie_date_info AS
(
    SELECT
        dm.name_id AS director_id,
        n.name AS director_name,
        m.id AS movie_id,
        m.date_published,
        m.duration,
        r.avg_rating,
        r.total_votes,
        LAG(m.date_published) OVER
        (
            PARTITION BY dm.name_id
            ORDER BY m.date_published
        ) AS previous_movie_date

    FROM director_mapping dm
    JOIN names n
        ON dm.name_id = n.id
    JOIN movie m
        ON dm.movie_id = m.id
    JOIN ratings r
        ON m.id = r.movie_id
)

SELECT
    director_id,
    director_name,
    COUNT(movie_id) AS number_of_movies,
    ROUND(AVG(DATEDIFF(date_published, previous_movie_date))) AS avg_inter_movie_days,
    ROUND(AVG(avg_rating),2) AS avg_rating,
    SUM(total_votes) AS total_votes,
    MIN(avg_rating) AS min_rating,
    MAX(avg_rating) AS max_rating,
    SUM(duration) AS total_duration

FROM movie_date_info

GROUP BY
    director_id,
    director_name

ORDER BY
    number_of_movies DESC,
    avg_rating DESC
LIMIT 9;

-- End Of Project