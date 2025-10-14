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
--Avg rating by state (10 hospital min)
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

**Interpretation.** Averaging the latest available star rating **by state** (and requiring **≥10 rated hospitals** to avoid tiny samples) shows a clear spread across the country. In this snapshot, states like **UT (4.03, n=32)**, **HI (4.00, n=11)**, **OR (3.94, n=50)**, **MN (3.91, n=66)**, and **WI (3.91, n=101)** sit at the top end, while larger systems such as **CA (3.01, n=273)** and **NY (2.31, n=131)** land lower on the list. Mid-pack states cluster around ~3.3–3.7 (e.g., **CO 3.88, n=51**; **IN 3.61, n=103**; **TX 3.34, n=238**). This pattern suggests most states hover near “average to above average,” with a handful of consistent standouts.

**How to read this.**
- We **exclude NULL ratings**, so states with many “Not Available” facilities may have fewer counted hospitals (smaller `n`), which can swing the average.
- The threshold **`HAVING COUNT(*) >= 10`** filters out ultra-small samples; e.g., HI (n=11) barely clears the bar—its mean is informative but still sensitive to a few hospitals.
- This is a **simple mean** over facilities; it’s **not weighted** by bed count, case mix, or population. Large states (e.g., CA, NY, FL) include many diverse hospital types, which can pull the average down relative to smaller, more homogeneous states.
- Values reflect the **latest rating per facility**, not a multi-year trend; states can move as new ratings are published.

### 3) What impact do various ownership types have on overall hospital star ratings?
```sql
--Ownership vs rating
SELECT hospital_ownership,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY hospital_ownership
ORDER BY avg_rating DESC;
```
Result:

<img width="527" height="245" alt="Screen Shot 2025-10-14 at 11 54 32 AM" src="https://github.com/user-attachments/assets/a692b4c5-d71e-464f-a264-8c5300a678af" />

**Interpretation.** Averaging the latest star rating **by ownership** shows meaningful differences. In this snapshot, **Physician-owned hospitals** rank highest (3.73, n=22), followed by **Voluntary non-profit** groups—Church (3.41, n=243), Private (3.34, n=1,696), and Other (3.29, n=291). Public entities tend to sit mid-pack—**Government–Local** (3.21, n=226) and **Hospital District/Authority** (3.12, n=313)—while **Proprietary** hospitals average lower (2.88, n=544). Very small categories such as **Government–Federal** (2.75, n=12), **VHA** (2.67, n=3), and **Tribal** (2.50, n=4) appear at the bottom but have tiny sample sizes.

**How to read this.**
- We **exclude NULL ratings**, so `n` reflects only facilities with a current star rating.
- This is an **unweighted mean per facility**; it doesn’t adjust for bed size, case mix, teaching status, or geography. Ownership groups with many small/rural hospitals (or different service mixes) can show different averages.
- Small-`n` categories (e.g., VHA, Tribal, Federal) are **high-variance**; treat those averages as directional, not definitive.

### 4) What impact does hospital types have on overall hospital star ratings?
```sql
--Hospital type vs rating
SELECT hospital_type,
       ROUND(AVG(hospital_rating)::numeric,2) AS avg_rating,
       COUNT(*) AS n
FROM hospital_full_latest
WHERE hospital_rating IS NOT NULL
GROUP BY hospital_type
ORDER BY avg_rating DESC;
```
Result:

<img width="495" height="86" alt="Screen Shot 2025-10-14 at 12 01 14 PM" src="https://github.com/user-attachments/assets/2b383d0e-5834-47c8-90e9-736c5d609403" />

**Interpretation.** Averaging the latest star rating **by hospital type** shows a clear split: **Critical Access Hospitals (CAHs)** lead with **3.62 (n=638)**, while **Acute Care Hospitals** average **3.14 (n=2,752)**. The tiny **Acute Care – Veterans Administration** group appears lowest at **2.67 (n=3)**, but that sample is too small to generalize.

**How to read this.**
- `n` counts facilities with a **current** rating (NULLs excluded).
- This is an **unweighted mean** per facility. CAHs are typically small rural hospitals with a narrower service mix; Acute Care hospitals are larger and handle more complex cases—those mix differences can influence averages.
- Very small categories (e.g., VA, n=3) are **high-variance**; treat those values as directional only.

### 5) What states have the most high-rated hospitals? (4-5★)
```sql
--States with most high-rated hospitals
SELECT state,
       SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END) AS four_plus,
       COUNT(*) AS total,
       ROUND(100.0 * SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END)
                    / NULLIF(COUNT(*),0), 1) AS pct_four_plus
FROM hospital_full_latest
GROUP BY state
ORDER BY four_plus DESC;
```
Result:

<img width="527" height="708" alt="Screen Shot 2025-10-14 at 12 08 54 PM" src="https://github.com/user-attachments/assets/e5e8b9bf-93ac-4020-90d1-b5339a86a1b4" />
<img width="526" height="440" alt="Screen Shot 2025-10-14 at 12 09 08 PM" src="https://github.com/user-attachments/assets/c236d2af-0175-4a08-881d-2b0f7b800efe" />

**Interpretation.** Ranking **states by the count of high-rated hospitals (4–5★)** highlights big systems by sheer volume—**TX = 101/456 (22.1%)**, **CA = 90/379 (23.7%)**, **OH = 71/194 (36.6%)**, **IL = 64/195 (32.8%)**. But looking at the **concentration** (the `%` column) tells a different story: mid-sized states such as **OR = 37/62 (59.7%)**, **ME = 21/38 (55.3%)**, **WI = 72/142 (50.7%)**, **UT = 25/51 (49.0%)**, and **ID = 22/48 (45.8%)** have a much higher share of 4–5★ facilities. At the low end, large/diverse systems like **NY = 21/189 (11.1%)** and **LA = 16/157 (10.2%)** show lower concentration despite many hospitals overall.  
**Takeaway:** use **both** the raw count (capacity) and the percentage (quality concentration) to compare states fairly.

**How to read this.**
- `total` includes **all** facilities in the latest snapshot, even those with **no rating**; that’s why percentages can be lower in states with many unrated hospitals.
- This is an **unweighted** facility count; it doesn’t account for bed size, case mix, or teaching status.
- Small denominators (e.g., states/territories with few hospitals) yield volatile percentages—treat with caution.

### 6) What cities have the most high-rated hospitals? (4-5★)
```sql
--Cities with most high-rated hopsitals
SELECT city, state,
       SUM(CASE WHEN hospital_rating >= 4 THEN 1 ELSE 0 END) AS four_plus,
       COUNT(*) AS total
FROM hospital_full_latest
GROUP BY city, state
HAVING COUNT(*) >= 5
ORDER BY four_plus DESC, total DESC;
```
Result: 

<img width="491" height="707" alt="Screen Shot 2025-10-14 at 12 16 42 PM" src="https://github.com/user-attachments/assets/21f6196f-9054-4137-8252-c75916ffcb7e" />
<img width="487" height="642" alt="Screen Shot 2025-10-14 at 12 16 55 PM" src="https://github.com/user-attachments/assets/bb770769-2f0e-4572-806c-8302ec192952" />
<img width="491" height="681" alt="Screen Shot 2025-10-14 at 12 17 58 PM" src="https://github.com/user-attachments/assets/c914ec4d-2232-40e0-9b2d-95b6354bd9bd" />
<img width="491" height="120" alt="Screen Shot 2025-10-14 at 12 18 09 PM" src="https://github.com/user-attachments/assets/4e1c59d3-f4e7-4593-a304-253a29ae2dc7" />

**Interpretation.** Counting **high-rated hospitals (4–5★) by city** surfaces the biggest hubs by volume—e.g., **Houston, TX = 7/28**, **Oklahoma City, OK = 5/19**, **Dallas, TX = 5/19**, **Austin, TX = 5/16**. But looking at **concentration** tells a richer story: several mid-size markets have a much higher share of 4–5★ facilities, like **Portland, OR = 5/9 (~55.6%)**, **Green Bay, WI = 4/7 (~57.1%)**, **Honolulu, HI = 4/6 (~66.7%)**, **Fort Worth, TX = 5/12 (~41.7%)**, **Seattle, WA = 4/9 (~44.4%)**, and **Omaha, NE = 5/11 (~45.5%)**. By contrast, very large metros (**Chicago 4/35 ≈ 11.4%**, **Los Angeles 3/19 ≈ 15.8%**, **New York 4/16 = 25.0%**) have many hospitals but a lower high-rating share—likely reflecting broader case-mix and hospital-type diversity.

**How to read this.**
- `total` counts **all** facilities in the city snapshot (including **unrated**), so % can be pulled down where there are many “No rating” hospitals.
- We kept cities with **≥5 facilities** (`HAVING COUNT(*) >= 5`) to avoid ultra-tiny samples, but some results are still sensitive to small `total`.
- Values are **unweighted by size**; one small hospital counts the same as a major academic center.

### 7) What is the overall ownership share by state?
```sql
--Ownership share by state
SELECT state, hospital_ownership, COUNT(*) AS n
FROM hospital_full_latest
GROUP BY state, hospital_ownership
ORDER BY state, n DESC;
```
Result:

<img width="416" height="190" alt="Screen Shot 2025-10-14 at 12 43 14 PM" src="https://github.com/user-attachments/assets/bec208eb-9af9-4927-a41a-f4269b8781b1" />

**Example — South Carolina (SC).** In the latest snapshot there are **66 facilities**.  
Ownership mix (by facility count, unweighted):

- **Voluntary non-profit – Private:** 31 (**~47.0%**)
- **Proprietary:** 17 (**~25.8%**)
- **Government – Hospital District/Authority:** 5 (**~7.6%**)
- **Voluntary non-profit – Other:** 4 (**~6.1%**)
- **Government – State:** 4 (**~6.1%**)
- **Government – Local:** 2 (**~3.0%**)
- **Veterans Health Administration:** 2 (**~3.0%**)
- **Department of Defense:** 1 (**~1.5%**)

**Interpretation.** SC is dominated by **non-profit private hospitals (~47%)** with a sizable **proprietary** presence (~26%). Public ownership is spread across state, local, and hospital-district entities (~17% combined), and there’s a small federal footprint (VHA/DoD ~4.5%). Counts include **all facilities** in the latest-per-facility view (rated and unrated) and are **not weighted** by beds or volume.

**Why only an example?** The complete ownership-by-state table is **400+ rows**, which isn’t readable in a README. To keep the project concise, I show one illustrative state (my own) and provide the **full results as a CSV** for anyone who wants the complete breakdown.

Full table: Full results (CSV): [outputs/ownership_by_state.csv](outputs/ownership_by_state.csv)

### 8) How many hospitals are missing a star rating by state?
```sql
--No ratings by state
SELECT state, COUNT(*) AS no_rating
FROM hospital_full_latest
WHERE hospital_rating IS NULL
GROUP BY state
ORDER BY no_rating DESC;
```
Result:

<img width="272" height="708" alt="Screen Shot 2025-10-14 at 12 35 38 PM" src="https://github.com/user-attachments/assets/cfc4025e-ad2b-453c-8cea-a352be2088a4" />
<img width="272" height="421" alt="Screen Shot 2025-10-14 at 12 35 50 PM" src="https://github.com/user-attachments/assets/f8fecd09-a347-4ea8-86fe-e7c85eebb3ba" />

**Interpretation.** This table counts hospitals **without a CMS overall star rating** (`hospital_rating IS NULL`) and orders states/territories by raw count. The largest concentrations are in big hospital markets—**TX (218)**, **CA (106)**, **LA (85)**, **KS (70)**, **OK (69)**, **MN (69)**, **OH (62)**, **PA (60)**, **NY (58)**, **FL (57)**—with additional clusters across **AZ/PR (52 each)** and many smaller counts elsewhere. Because these are **raw counts**, they mostly reflect how many hospitals a state has and its facility mix (e.g., more specialty or newly opened hospitals), not necessarily data quality. Also note the dataset includes **territories and DC** (e.g., PR, GU, AS, MP, DC), so it’s broader than the 50 states. For cross-state comparisons, a more informative lens is **% unrated** (unrated ÷ total hospitals in the state) rather than counts alone.

**About the “No rating” rows.** “No rating” does **not** imply poor performance. It usually means the hospital lacked enough measure data for a composite, is a specialty/exempt facility, is newly opened/closed, or the latest record was reported as **Not Available**. In this project, when computing any state-level averages or “% of 4–5★,” unrated hospitals are **excluded from numerators and denominators** and are reported separately as **coverage** (e.g., “TX: 218 unrated; X% of hospitals unrated”). This avoids bias from missingness while staying transparent about where rating gaps are concentrated.










