-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/analysis/01_profile.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Profile layer — baseline exploration of both datasets before
--           any deeper analysis. Validates data boundaries, scale, and
--           identifies key artists across both tables.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Billboard date range
-- PURPOSE: Establish the temporal boundaries of the Billboard dataset.
--          Critical for determining the valid analysis window when joining
--          to Grammy data. Any Grammy wins outside this range will have
--          no Billboard data to compare against.
-- =============================================================================

SELECT
    MIN(chart_date) AS earliest_chart,
    MAX(chart_date) AS latest_chart,
    COUNT(DISTINCT chart_date) AS total_weeks
FROM billboard_hot100;

-- Finding: Billboard runs from 1958-08-04 to 2021-11-06 (3,301 weekly charts)


-- =============================================================================
-- QUERY 2: Grammy date range
-- PURPOSE: Establish the temporal boundaries of the Grammy dataset and
--          identify the overlap with Billboard data.
-- =============================================================================

SELECT
    MIN(year) AS earliest_year,
    MAX(year) AS latest_year,
    COUNT(DISTINCT year) AS total_years
FROM grammy_nominations;

-- Finding: Grammy runs from 1958 to 2026 (68 years)
-- IMPORTANT: Grammy wins from 2022-2026 have no Billboard data to compare
--            against. All core analysis queries filter to year <= 2021
--            to ensure we only analyze years where both datasets overlap.
-- Valid analysis window: 1958 to 2021 (63 years)


-- =============================================================================
-- QUERY 3: Billboard unique artists and songs
-- PURPOSE: Understand the scale and diversity of the Billboard dataset.
--          A high unique artist count confirms the data is not skewed
--          toward a handful of acts.
-- =============================================================================

SELECT
    COUNT(DISTINCT artist) AS unique_artists,
    COUNT(DISTINCT song)   AS unique_songs
FROM billboard_hot100;

-- Finding: 10,205 unique artists, 24,620 unique songs
-- Confirms the dataset is rich and diverse across 63 years of chart history


-- =============================================================================
-- QUERY 4: Grammy unique artists and award categories
-- PURPOSE: Understand the scale of the Grammy dataset and how many
--          distinct award categories exist. A high category count confirms
--          the need to filter down to relevant categories in genre analysis.
-- =============================================================================

SELECT
    COUNT(DISTINCT artist)  AS unique_artists,
    COUNT(DISTINCT award)   AS unique_awards
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != '';

-- Finding: 4,517 unique Grammy artists across 494 award categories
-- 494 categories is very high — confirms that genre/category filtering
-- will be essential in Section 5 analysis to avoid noise from obscure
-- classical, children's, and technical categories


-- =============================================================================
-- QUERY 5: Top 10 most charting Billboard artists
-- PURPOSE: Identify which artists have the strongest long term commercial
--          presence on the Hot 100. total_chart_entries counts every weekly
--          appearance, not just unique songs — so an artist with one song
--          on the chart for 20 weeks contributes 20 entries.
-- =============================================================================

SELECT
    artist,
    COUNT(*)              AS total_chart_entries,
    COUNT(DISTINCT song)  AS unique_songs,
    MIN(peak_rank)        AS best_chart_position
FROM billboard_hot100
GROUP BY artist
ORDER BY total_chart_entries DESC
LIMIT 10;

-- Finding: Taylor Swift leads with 1,023 chart entries across 120 unique songs
-- Kenny Chesney and Tim McGraw appear despite never reaching #1 —
-- showing consistent mid-chart longevity vs. peak performance


-- =============================================================================
-- QUERY 6: Top 10 most nominated Grammy artists
-- PURPOSE: Identify which artists have the strongest critical recognition
--          from the Recording Academy. Win rate (total_wins / total_nominations)
--          reveals how nominations translate to actual awards.
-- NOTE:    CASE WHEN is used instead of COUNT(winner) because COUNT would
--          count all non-null rows regardless of value. CASE WHEN + SUM
--          counts only rows where winner = true.
-- =============================================================================

SELECT
    artist,
    COUNT(*) AS total_nominations,
    SUM(CASE WHEN winner = true THEN 1 ELSE 0 END) AS total_wins
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != ''
AND year <= 2021
GROUP BY artist
ORDER BY total_nominations DESC
LIMIT 10;

-- Finding: Willie Nelson leads nominations (46) but has a low win rate (17%)
-- Tony Bennett has a 47% win rate, U2 has 51%
-- Nomination volume does not reliably predict win success


-- =============================================================================
-- QUERY 7: Artists appearing in both Billboard top 50 and Grammy top 50
-- PURPOSE: Identify artists who achieved both commercial dominance (Billboard)
--          and critical recognition (Grammy) simultaneously. Uses two CTEs
--          to isolate each top 50 list then joins on artist name to find
--          the overlap. INNER JOIN ensures only artists in BOTH lists appear.
-- NOTE:    Artist name standardization is not applied here as this is a
--          profile query. Cleaning CTEs are applied in analysis sections
--          3, 4, and 5 where join accuracy is critical.
-- =============================================================================

WITH billboard_top50 AS (
    SELECT
        artist,
        COUNT(*)              AS total_chart_entries,
        COUNT(DISTINCT song)  AS unique_songs,
        MIN(peak_rank)        AS best_chart_position
    FROM billboard_hot100
    GROUP BY artist
    ORDER BY total_chart_entries DESC
    LIMIT 50
),
grammy_top50 AS (
    SELECT
        artist,
        COUNT(*) AS total_nominations,
        SUM(CASE WHEN winner = true THEN 1 ELSE 0 END) AS total_wins
    FROM grammy_nominations
    WHERE artist IS NOT NULL
    AND artist != ''
    AND year <= 2021
    GROUP BY artist
    ORDER BY total_nominations DESC
    LIMIT 50
)
SELECT
    b.artist,
    b.total_chart_entries,
    b.unique_songs,
    b.best_chart_position,
    g.total_nominations,
    g.total_wins
FROM billboard_top50 b
JOIN grammy_top50 g ON b.artist = g.artist
ORDER BY g.total_nominations DESC;

-- Key Findings:
--   Stevie Wonder and Aretha Franklin: most balanced — top 50 in both
--   Elton John: 889 chart entries but only 2 Grammy wins from 23 nominations
--               — commercially dominant but repeatedly passed over
--   Mariah Carey: 621 chart entries, 24 nominations but only 3 wins
--                 — similar pattern of high commercial/low Grammy conversion
--   Taylor Swift: leads Billboard all time but Grammy dominance is recent
--                 and largely falls after the 2021 analysis cutoff