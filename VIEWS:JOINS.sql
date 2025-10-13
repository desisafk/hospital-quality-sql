--VIEWS/ JOINS

--one row per facility with original table
create or replace view hospital_general_clean as
select
	"ZIP Code" as zip_code,
	"Facility ID" as facility_id,
	"Hospital Type" as hospital_type,
	"Hospital Ownership" as hospital_ownership,
	"Hospital overall rating" as hospital_rating,
	"Facility Name" as facility_name,
	"address",
	"City/Town" as city,
	"state",
	"Telephone Number" as phone_number
from hospital_general;
	
-- ratings by facility per year
CREATE OR REPLACE VIEW hospital_star_ratings AS
SELECT
  "Facility ID"::text AS facility_id,
  "Facility Name" AS facility_name,
  "City",
  "State",
  "ZIP Code" AS zip_code,
  "Hospital Type" AS hospital_type,
  "Hospital Ownership" AS hospital_ownership,
  "Emergency Services",
  NULLIF(regexp_replace("Hospital overall rating", '[^0-9]', '', 'g'), '')::int AS hospital_rating,
  NULLIF("Mortality national comparison", '') AS mortality_rating,
  NULLIF("Readmission national comparison", '') AS readmission_rating,
  NULLIF("Patient experience national comparison", '') AS patient_experience_rating,
  NULLIF("Timeliness of care national comparison", '') AS timeliness_rating,
  NULLIF("Efficient use of medical imaging national comparison", '') AS imaging_rating,
  "Year"::int AS rating_year
FROM hospital_star_ratings_raw;

--joining both tables
CREATE OR REPLACE VIEW hospital_full AS
SELECT
  g.facility_id::bigint as facility_id,
  g.facility_name,
  g.city,
  g.state,
  g.zip_code,
  g.hospital_type,
  g.hospital_ownership,
  s.hospital_rating,
  s.rating_year
FROM hospital_general_clean g
LEFT JOIN hospital_star_ratings s
  ON g.facility_id::bigint = s.facility_id::bigint;

--one row per facility w/ most recent rating (main view)
CREATE OR REPLACE VIEW hospital_full_latest AS
WITH s_ranked AS (
  SELECT
    (facility_id)::numeric(20,0) AS fid,
    hospital_rating,
    rating_year,
    ROW_NUMBER() OVER (
      PARTITION BY (facility_id)::numeric(20,0)
      ORDER BY rating_year DESC
    ) AS rn
  FROM hospital_star_ratings
)
SELECT
  (g.facility_id)::numeric(20,0)::text AS facility_id,
  g.facility_name,
  g.city,
  g.state,
  g.zip_code,
  g.hospital_type,
  g.hospital_ownership,
  s.hospital_rating,
  s.rating_year
FROM hospital_general_clean g
LEFT JOIN s_ranked s
  ON (g.facility_id)::numeric(20,0) = s.fid
 AND s.rn = 1;


-- QA CODE 

-- Type + counts
SELECT 'general' src, COUNT(*) rows, COUNT(DISTINCT facility_id) distinct_ids FROM hospital_general_clean
UNION ALL
SELECT 'stars'  , COUNT(*), COUNT(DISTINCT facility_id) FROM hospital_star_ratings
UNION ALL
SELECT 'full'   , COUNT(*), COUNT(DISTINCT facility_id) FROM hospital_full;

-- ID non-integer floats on the general side
SELECT facility_id
FROM hospital_general_clean
WHERE facility_id <> round(facility_id)
LIMIT 20;

-- Unmatched on each side (normalize both sides the same way)
WITH g AS (
  SELECT (facility_id)::numeric(20,0) AS fid FROM hospital_general_clean
),
s AS (
  SELECT (facility_id)::numeric(20,0) AS fid FROM hospital_star_ratings
)
SELECT
  (SELECT COUNT(*) FROM g LEFT JOIN s USING(fid) WHERE s.fid IS NULL) AS general_ids_missing_in_stars,
  (SELECT COUNT(*) FROM s LEFT JOIN g USING(fid) WHERE g.fid IS NULL) AS star_ids_missing_in_general;

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










