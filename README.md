# <p align="center">Hospital Quality (CMS) — SQL ELT & Analysis</p>
# <p align="center"><img width="2560" height="1149" alt="image" src="https://github.com/user-attachments/assets/44d61456-46a7-4fcc-889f-613a0d4b6b65" />
</p>

**Tools Used:** PostgreSQL, DBeaver (or pgAdmin), Excel/CSV exports

**Datasets Used:**  
- [CMS Hospital General Information](https://data.cms.gov/provider-data/dataset/xubh-q36u)  
- [CMS Overall Hospital Quality Star Rating](https://data.cms.gov/provider-data/topics/hospitals/overall-hospital-quality-star-rating/)

**SQL Analysis (Code):**  
- [`sql/01_views.sql`](VIEWS:JOINS.sql) — views (clean → typed → joined → latest)  
- [`sql/02_qa.sql`](sql/02_qa.sql) — data quality checks  
- [`sql/03_analysis.sql`](sql/03_analysis.sql) — core analysis queries

---

- **Business Problem:** Stakeholders need a clean, analysis-ready view of hospital quality across states, ownership, and hospital types. Raw CMS files include multiple years, mixed ID types (float vs text), and “Not Available” ratings—making direct analysis noisy and error-prone.

- **How I Solved It:** Built a small **ELT pipeline in SQL (PostgreSQL)** that stages/types the data, **normalizes Facility IDs**, joins across sources, and snapshots **one latest rating per facility** with a window function. Then I ran focused analysis (distribution, averages by state/type/ownership, high-rated counts) and exported CSVs for BI.

---

## Questions I Wanted To Answer From the Dataset

> The queries below run against **`hospital_full_latest`** unless noted.  
> This view guarantees **one row per facility** using `ROW_NUMBER()`.

### 1) What’s the distribution of hospitals by latest star rating (incl. “No rating”)?
```sql
SELECT
  COALESCE(hospital_rating::text, 'No rating') AS rating_bucket,
  COUNT(*) AS n
FROM hospital_full_latest
GROUP BY rating_bucket
ORDER BY
  CASE WHEN rating_bucket = 'No rating' THEN 2 ELSE 1 END,
  NULLIF(rating_bucket, 'No rating')::int NULLS LAST;

