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
