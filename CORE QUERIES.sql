--CORE QUERIES

--Overall rating distribution
SELECT hospital_rating, COUNT(*) AS n
FROM hospital_full_latest
GROUP BY hospital_rating
ORDER BY hospital_rating;

--Avg rating by state (10 hospital min)
SELECT state,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY state
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC;

--Ownership vs rating
SELECT hospital_ownership,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY hospital_ownership
ORDER BY avg_rating DESC;

--Hospital type vs rating
SELECT hospital_type,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY hospital_type
ORDER BY avg_rating DESC;

--States with most high-rated hospitals
SELECT state,
       SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END) AS four_plus,
       COUNT(*) AS total,
       ROUND(100.0 * SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END)
                    / NULLIF(COUNT(*),0), 1) AS pct_four_plus
FROM hospital_full_latest
GROUP BY state
ORDER BY four_plus DESC;

--Cities with most high-rated hopsitals
SELECT city, state,
       SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END) AS four_plus,
       COUNT(*) AS total
FROM hospital_full_latest
GROUP BY city, state
HAVING COUNT(*) >= 5
ORDER BY four_plus DESC, total DESC;

--Ownership share by state
SELECT state, hospital_ownership, COUNT(*) AS n
FROM hospital_full_latest
GROUP BY state, hospital_ownership
ORDER BY state, n DESC;


--No ratings by state
SELECT state, COUNT(*) AS no_rating
FROM hospital_full_latest
WHERE hospital_rating IS NULL
GROUP BY state
ORDER BY no_rating DESC;










