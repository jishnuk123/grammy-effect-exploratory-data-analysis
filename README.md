# The Grammy Effect: Does Winning a Grammy Improve Billboard Chart Performance?

An end-to-end SQL data analysis project measuring the commercial impact of Grammy Award wins on Billboard Hot 100 chart performance across 63 years of music history (1958–2021).

---

## Project Overview

The Grammy Award is widely considered the most prestigious recognition in the music industry. But does winning one actually make an artist more commercially successful? This project answers that question by analyzing Billboard Hot 100 chart data before and after an artist's first Grammy win — measuring what I call **The Grammy Effect**.

**Key Finding:** Across 191 Grammy winning artists with sufficient Billboard data, **57% saw improved chart performance** in the 3 years following their first win, with an average rank improvement of 4.8 positions. However, the effect varies dramatically by genre and by where the artist was in their career before winning.

---

## Tools & Technologies

- **PostgreSQL** — database design, data loading, and all analysis queries
- **pgAdmin 4** — database management interface
- **Tableau Public** — interactive dashboard and data visualization
- **Git / GitHub** — version control and project documentation

---

## SQL Concepts Demonstrated

| Concept | Where Used |
|---|---|
| `CREATE TABLE`, `COPY`, `ALTER TABLE` | Schema design and data loading |
| `COUNT`, `MIN`, `MAX`, `AVG`, `GROUP BY` | Profile and aggregation layer |
| `RANK()`, `DENSE_RANK()` | Artist ranking comparisons |
| `NTILE()`, `PERCENT_RANK()` | Genre tier analysis |
| `LAG()`, `LEAD()` | Year over year change analysis |
| Window frames (`ROWS BETWEEN`) | Rolling averages |
| Multi-level CTEs | Grammy Effect pre/post analysis |
| `CASE WHEN` | Conditional aggregation and classification |
| `REGEXP_REPLACE` | Artist name standardization across datasets |
| `DATE_TRUNC`, `EXTRACT` | Time series aggregation |

---

## Data Sources

Both datasets are sourced from Kaggle. Download the CSV files and place them in `/data/` before running any SQL scripts.

| Dataset | Source | Rows |
|---|---|---|
| Billboard Hot 100 (1958–2021) | [Kaggle — dhruvildave](https://www.kaggle.com/datasets/dhruvildave/billboard-the-hot-100-songs) | 330,087 |
| Grammy Winners & Nominees (1958–2024) | [Kaggle — johnpendenque](https://www.kaggle.com/datasets/johnpendenque/grammy-winners-and-nominees-from-1965-to-2024) | 25,535 |

---

## Project Structure

```
grammy-effect-sql-analysis/
│
├── data/
│   ├── charts.csv              ← Billboard Hot 100 (download from Kaggle)
│   └── grammies_v4.csv         ← Grammy nominations (download from Kaggle)
│
├── sql/
│   ├── schema/
│   │   └── create_tables.sql   ← Table definitions and data loading
│   ├── cleaning/
│   │   └── cleaning.sql        ← Null audit, data quality findings, cleaning CTE
│   └── analysis/
│       ├── 01_profile.sql      ← Dataset boundaries, scale, top artists
│       ├── 02_artists.sql      ← Billboard vs Grammy rank gap analysis
│       ├── 03_time.sql         ← Decade trends, rolling averages, YoY change
│       ├── 04_grammy_effect.sql ← Core pre/post win chart performance analysis
│       └── 05_genres.sql       ← Grammy Effect broken down by genre category
│
├── tableau/                    ← Dashboard screenshots
│
└── README.md
```

---

## How to Run This Project

**1. Clone the repository**
```bash
git clone https://github.com/yourusername/grammy-effect-sql-analysis.git
```

**2. Download the datasets**

Download both CSVs from the Kaggle links above and place them in the `/data/` folder.

**3. Create the database**

Open pgAdmin, create a new database called `grammy_effect`, then open the Query Tool.

**4. Run the schema script**
```
sql/schema/create_tables.sql
```
Update the file path in the `COPY` commands to match your local machine before running.

**5. Run the analysis scripts in order**
```
sql/cleaning/cleaning.sql
sql/analysis/01_profile.sql
sql/analysis/02_artists.sql
sql/analysis/03_time.sql
sql/analysis/04_grammy_effect.sql
sql/analysis/05_genres.sql
```

---

## Key Findings

### 1. The Grammy Effect Is Real But Modest
Across 191 Grammy winning artists, 57% saw improved Billboard chart performance in the 3 years after their first win. The average rank improvement was 4.8 positions — modest at the population level but masking dramatic individual differences.

### 2. The Effect Is Strongest for Mid-Tier Artists
Artists who were already dominating the chart before winning (top 20 average rank) showed little to no improvement — and often declined. The biggest beneficiaries were mid-tier artists breaking through to mainstream audiences:

| Artist | First Win | Rank Improvement |
|---|---|---|
| Melissa Etheridge | 1992 | +61.7 |
| Kenny Rogers | 1977 | +61.5 |
| Ray Charles | 1960 | +56.8 |
| Aretha Franklin | 1967 | +50.9 |
| Billie Eilish | 2019 | +36.5 |

### 3. Pop Winners Benefit Most, Hip Hop and Gospel Least

| Genre | Avg Rank Improvement | % Improved |
|---|---|---|
| Pop | +6.6 | 65% |
| General Field | +4.9 | 60% |
| Rock | +4.7 | 58% |
| Country | +3.2 | 52% |
| R&B | +2.2 | 46% |
| Hip Hop | +0.7 | 51% |
| Gospel | -13.2 | 33% |

### 4. Chart Diversity Peaked in the 1960s and Is Recovering Via Streaming
Unique artists on the Hot 100 peaked in the early 1960s (~400/year), declined through the 1980s label consolidation era (~300/year), and has surged back to 440+ in 2017–2021 as streaming democratized chart access.

### 5. The Chart Is Becoming More Winner-Take-All
Average peak rank hit its lowest point (34-35) in 2019–2021, meaning songs are peaking higher on average than any era since the 1970s. Streaming mega-hits are monopolizing top positions more aggressively than ever before.

### 6. Elton John Is the Most Interesting Anomaly
889 Billboard chart entries (2nd all time) but only 2 Grammy wins from 23 nominations — the largest gap between commercial dominance and Grammy recognition of any major artist in the dataset.

---

## Data Cleaning Decisions

| Issue | Decision |
|---|---|
| Null artists (11,713 Grammy rows) | Filtered out — craft/technical awards with no performing artist |
| Accented characters (Beyoncé vs Beyonce) | Normalized with `REGEXP_REPLACE` |
| Featured artists in Billboard names | Stripped with `REGEXP_REPLACE` before joining |
| Casing inconsistencies (6lack vs 6LACK) | Normalized with `LOWER()` |
| Grammy years 2022–2026 | Excluded — no Billboard data exists for those years |
| Analysis window | 1958–2021 (63 years of overlapping data) |
| Match rate (32% of Grammy artists matched to Billboard) | Expected — non-pop genres rarely produce Hot 100 singles |

---

## Tableau Dashboard

[Link to Tableau Public dashboard]

---

## Author
Jishnu Kandala 
[[Your LinkedIn](https://www.linkedin.com/in/jishnu-kandala-a58a49406/)]  
[\[Your GitHub\]](https://github.com/jishnuk123)