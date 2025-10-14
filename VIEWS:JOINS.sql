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
