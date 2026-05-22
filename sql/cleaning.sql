-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/cleaning.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Documents all data quality findings and defines the core cleaning
--           CTE that is used as the foundation of every analysis query.
--           Raw data is never altered — all cleaning is done on the fly
--           via CTEs to keep the process transparent and reproducible.
-- =============================================================================


-- =============================================================================
-- STEP 1: NULL AUDIT
-- Run these diagnostic queries to profile data quality in both tables
-- before making any cleaning decisions
-- =============================================================================

-- Null audit: Billboard Hot 100
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(*) FILTER (WHERE chart_date IS NULL)         AS null_dates,
    COUNT(*) FILTER (WHERE rank IS NULL)               AS null_ranks,
    COUNT(*) FILTER (WHERE song IS NULL)               AS null_songs,
    COUNT(*) FILTER (WHERE artist IS NULL)             AS null_artists,
    COUNT(*) FILTER (WHERE last_week IS NULL)          AS null_last_week,
    COUNT(*) FILTER (WHERE peak_rank IS NULL)          AS null_peak_rank,
    COUNT(*) FILTER (WHERE weeks_on_board IS NULL)     AS null_weeks
FROM billboard_hot100;

-- Findings:
--   total_rows:    330,087
--   null_last_week: 32,312  → expected, means the song was new to the chart
--                             that week. No action needed.
--   All other columns: 0 nulls 


-- Null audit: Grammy Nominations
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(*) FILTER (WHERE year IS NULL)               AS null_years,
    COUNT(*) FILTER (WHERE award IS NULL)              AS null_awards,
    COUNT(*) FILTER (WHERE artist IS NULL)             AS null_artists,
    COUNT(*) FILTER (WHERE song_or_album IS NULL)      AS null_songs,
    COUNT(*) FILTER (WHERE winner IS NULL)             AS null_winners
FROM grammy_nominations;

-- Findings:
--   total_rows:      25,535
--   null_artists:    11,713  → these are craft/technical awards (Best Album
--                             Cover, Best Arrangement etc.) where the credited
--                             person is stored in the producers column instead.
--                             These cannot be joined to Billboard and are
--                             filtered out in every analysis query.
--   null_song_or_album:  22  → incomplete historical records from early 1960s.
--                             Negligible impact, left in raw data.
--   All other columns: 0 nulls 


-- =============================================================================
-- STEP 2: ARTIST NAME INVESTIGATION
-- The entire project depends on joining both tables on artist name.
-- These queries investigate how artist names differ between datasets.
-- =============================================================================

-- Check how Billboard formats artist names (sample)
SELECT DISTINCT artist
FROM billboard_hot100
ORDER BY artist
LIMIT 20;

-- Check how Grammy formats artist names (sample)
SELECT DISTINCT artist
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != ''
ORDER BY artist
LIMIT 20;

-- Using a pecific example of how is Beyoncé stored in each dataset?
SELECT DISTINCT artist
FROM billboard_hot100
WHERE LOWER(artist) LIKE '%beyonce%';

SELECT DISTINCT artist
FROM grammy_nominations
WHERE LOWER(artist) LIKE '%bey%';

-- Findings - three problems identified:
--
--   Problem 1: ACCENTED CHARACTERS
--     Grammy stores "Beyoncé" (with accent)
--     Billboard stores "Beyonce" (without accent)
--     To Fix: normalize accented characters with REGEXP_REPLACE
--
--   Problem 2: FEATURED ARTISTS
--     Billboard stores features inside the artist field:
--     "Beyonce Featuring Jay Z", "Lady Gaga Featuring Beyonce"
--     Grammy stores only the primary artist: "Beyoncé"
--     To Fix: strip everything after Featuring/Feat./Ft./With/Duet
--
--   Problem 3: CASING INCONSISTENCIES
--     Billboard: "6lack"
--     Grammy:    "6LACK"
--     To Fix: normalize with LOWER()


-- =============================================================================
-- STEP 3: MATCH RATE ANALYSIS
-- After applying cleaning logic, how many Grammy artists can be
-- matched to a Billboard artist?
-- =============================================================================

-- Total unique Grammy artists after filtering nulls
SELECT COUNT(DISTINCT LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g')))) 
    AS total_grammy_artists
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != '';
-- Result: 4,477 unique Grammy artists

-- Total matched artists after applying cleaning CTE (see Step 4 below)
-- Result: 1,434 matched artists
-- Match rate: 1,434 / 4,477 = ~32%

-- Investigation: what award categories are in the unmatched artists?
SELECT DISTINCT award
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != ''
AND LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) NOT IN (
    SELECT DISTINCT LOWER(TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
        '[éèêë]', 'e', 'g'
    )))
    FROM billboard_hot100
)
ORDER BY award
LIMIT 20;

-- Finding: the 68% unmatched artists are overwhelmingly from non-pop categories:
-- classical, gospel, Latin, jazz, bluegrass, children's music etc.
-- These genres rarely produce Billboard Hot 100 singles.
-- The 32% match rate is expected and does not compromise the analysis —
-- it covers all major pop, R&B, hip-hop, rock, and country artists
-- that are the focus of the Grammy Effect study.


-- =============================================================================
-- STEP 4: CORE CLEANING CTE
-- This CTE is the foundation of every analysis query in this project.
-- It standardizes artist names in both tables so joins work reliably.
-- Copy and paste this block at the top of every analysis query.
-- =============================================================================

WITH billboard_cleaned AS (
    SELECT
        id,
        chart_date,
        rank,
        peak_rank,
        weeks_on_board,
        last_week,
        song,
        -- Standardize artist name:
        --   1. Strip featured artists (everything after Featuring/Feat./Ft./With/Duet)
        --      so "Beyonce Featuring Jay Z" becomes "Beyonce"
        --   2. Replace accented e variants (é è ê ë) with plain e
        --      so "Beyoncé" matches "Beyonce"
        --   3. LOWER() to remove casing differences ("6LACK" = "6lack")
        --   4. TRIM() to remove any leading/trailing whitespace
        LOWER(
            TRIM(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
                    '[éèêë]', 'e', 'g'
                )
            )
        ) AS artist_clean
    FROM billboard_hot100
),
grammy_cleaned AS (
    SELECT
        id,
        year,
        award,
        winner,
        song_or_album,
        -- Standardize artist name:
        --   1. Replace accented e variants with plain e
        --   2. LOWER() to remove casing differences
        --   3. TRIM() to remove any leading/trailing whitespace
        --   Note: featured artist stripping not needed here as Grammy
        --   stores only the primary artist
        LOWER(
            TRIM(
                REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g')
            )
        ) AS artist_clean
    FROM grammy_nominations
    WHERE artist IS NOT NULL        -- exclude craft/technical award rows
    AND artist != ''                -- exclude empty string artists
)

-- Verify join match count
SELECT COUNT(DISTINCT g.artist_clean) AS matched_artists
FROM grammy_cleaned g
INNER JOIN billboard_cleaned b ON b.artist_clean = g.artist_clean;
-- Result: 1,434 matched artists 


-- =============================================================================
-- CLEANING DECISIONS SUMMARY
-- =============================================================================

-- | Issue                          | Decision                                  |
-- |--------------------------------|-------------------------------------------|
-- | Null artists (11,713 rows)     | Filter out in every query via CTE         |
-- | Accented characters            | Normalize with REGEXP_REPLACE             |
-- | Featured artists in Billboard  | Strip with REGEXP_REPLACE                 |
-- | Casing inconsistencies         | Normalize with LOWER()                    |
-- | Null song_or_album (22 rows)   | Leave in raw data, negligible impact      |
-- | 32% match rate                 | Expected - non-pop genres rarely chart    |
-- | last_week nulls (32,312 rows)  | Expected - indicates new chart entry      |