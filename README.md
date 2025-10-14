# <p align="center">Hospital Quality (CMS) — SQL ELT & Analysis</p>
# <p align="center"><img width="2560" height="1149" alt="image" src="https://github.com/user-attachments/assets/44d61456-46a7-4fcc-889f-613a0d4b6b65" />
</p>

**Tools Used:** PostgreSQL, DBeaver (or pgAdmin), Excel/CSV exports

**Datasets Used:**  
- [CMS Hospital General Information](https://data.cms.gov/provider-data/dataset/xubh-q36u)  
- [CMS Overall Hospital Quality Star Rating](https://data.cms.gov/provider-data/topics/hospitals/overall-hospital-quality-star-rating/)

**SQL Analysis (Code):**  
- [`sql/01_views.sql`](https://github.com/desisafk/hospital-quality-sql/blob/776f55b787456f8285e5a219599cdd5f2f0199e6/VIEWS%3AJOINS.sql) — views (clean → typed → joined → latest)  
- [`sql/02_qa.sql`](https://github.com/desisafk/hospital-quality-sql/blob/b7dada8352ffe789b5e14b96a1484f2ef85b8d9c/QA%20CODE.sql) — data quality checks  
- [`sql/03_analysis.sql`](https://github.com/desisafk/hospital-quality-sql/blob/b7dada8352ffe789b5e14b96a1484f2ef85b8d9c/CORE%20QUERIES.sql) — core analysis queries

---

- **Business Problem:** Stakeholders need a clean, analysis-ready view of hospital quality across states, ownership, and hospital types. Raw CMS files include multiple years, mixed ID types (float vs text), and “Not Available” ratings—making direct analysis noisy and error-prone.

- **How I Solved It:** Built a small **ELT pipeline in SQL (PostgreSQL)** that stages/types the data, **normalizes Facility IDs**, joins across sources, and snapshots **one latest rating per facility** with a window function. Then I ran focused analysis (distribution, averages by state/type/ownership, high-rated counts) and exported CSVs for BI.

---

## Questions I Wanted To Answer From the Dataset

> The queries below run against **`hospital_full_latest`** unless noted.  
> This view guarantees **one row per facility** using `ROW_NUMBER()`.

### 1) What’s the latest overall star rating distribution of hospitals in the US?
```sql
--Overall rating distribution
SELECT hospital_rating, COUNT(*) AS n
FROM hospital_full_latest
GROUP BY hospital_rating
ORDER BY hospital_rating;
```
Result:

<img width="288" height="157" alt="Screen Shot 2025-10-14 at 11 26 37 AM" src="https://github.com/user-attachments/assets/a539d471-d730-414c-9aa1-1ae601dc8154" />

**Interpretation.** The latest-per-facility distribution shows a long middle with 3★–4★ hospitals making up the largest share (3★ = 1,037; 4★ = 1,086), a smaller tail at the extremes (1★ = 212; 5★ = 393), and a sizable “No rating” bucket (1,988). In this context, the CMS star rating is a summary measure of overall quality; higher stars generally indicate stronger performance across multiple domains (e.g., mortality, readmission, patient experience). The skew toward 3–4★ suggests most facilities cluster around average-to-above-average performance, with relatively few at the very high or very low end—typical of composite quality metrics.  

**About the “No rating” rows.** “No rating” does **not** mean poor quality; it means the hospital either had no matching stars record in the dataset or the latest year’s rating was reported as “Not Available.” For any averages or “% of 4–5★” metrics in this project, those rows are excluded from the numerator/denominator and are reported separately as coverage. This keeps summary stats from being biased by missingness while staying transparent about data gaps.

### 2) What is the average rating by state? (10 hospital minimum)
```sql
SELECT state,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY state
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC;
```
Result: 

<img width="360" height="707" alt="Screen Shot 2025-10-14 at 11 43 18 AM" src="https://github.com/user-attachments/assets/698e1524-fdcb-44e5-b208-ec073a64fafc" />
<img width="357" height="301" alt="Screen Shot 2025-10-14 at 11 43 28 AM" src="https://github.com/user-attachments/assets/b7f40431-9687-482e-a76d-56f83d201c8b" />

