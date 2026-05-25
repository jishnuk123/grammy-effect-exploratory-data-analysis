-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/analysis/05_genres.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Genre layer — determines which Grammy award categories produce
--           the strongest Billboard chart improvement after winning.
--           Uses NTILE() to bucket artists into improvement quartiles and
--           PERCENT_RANK() to show each artist's relative standing within
--           the full population of Grammy winners analyzed.
-- CONCEPTS: NTILE(n) divides the result set into n equal buckets ordered
--           by a specified column. NTILE(4) creates quartiles:
--             1 = top 25% of improvers
--             2 = next 25%
--             3 = next 25%
--             4 = bottom 25% (biggest decliners)
--           PERCENT_RANK() assigns each row a value between 0 and 1
--           showing its relative position in the ordered result set.
--           A PERCENT_RANK() of 0.95 means that row scored better than
--           95% of all rows in the window.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Billboard charting artists by Grammy award category
-- PURPOSE: Identify which Grammy award categories attract the most artists
--          who also appear on the Billboard Hot 100. This establishes which
--          categories are relevant for cross-dataset analysis and confirms
--          that mainstream categories (Record/Album of the Year) dominate.
-- =============================================================================

SELECT
    g.award,
    COUNT(DISTINCT LOWER(TRIM(REGEXP_REPLACE(g.artist, '[éèêë]', 'e', 'g')))) AS charting_artists,
    SUM(CASE WHEN g.winner = true THEN 1 ELSE 0 END) AS total_winners
FROM grammy_nominations g
WHERE g.artist IS NOT NULL
AND g.artist != ''
AND g.year <= 2021
AND LOWER(TRIM(REGEXP_REPLACE(g.artist, '[éèêë]', 'e', 'g'))) IN (
    SELECT DISTINCT LOWER(TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
        '[éèêë]', 'e', 'g'
    )))
    FROM billboard_hot100
)
GROUP BY g.award
ORDER BY charting_artists DESC
LIMIT 15;

-- Finding: Record of the Year (207 charting artists) and Album of the Year
-- (175 charting artists) dominate — confirming the General Field categories
-- attract the most mainstream commercially active artists.
-- Pop, Rock, R&B, Rap categories follow with 50-75 charting artists each.


-- =============================================================================
-- QUERY 2: Grammy Effect by genre category using NTILE() and PERCENT_RANK()
-- PURPOSE: Measure which broad genre categories produce the strongest
--          Billboard chart improvement after winning. Award names are
--          mapped to genre buckets using ILIKE pattern matching in a
--          CASE WHEN statement inside the grammy_winners CTE.
-- STRUCTURE: Six chained CTEs building on the Grammy Effect methodology
--            from 04_grammy_effect.sql with genre_category added:
--   grammy_winners  → first win year + genre category per artist
--   billboard_yearly → avg chart rank per artist per year
--   pre_post        → labels years as pre_win or post_win
--   aggregated      → pivots pre/post into columns
--   improvements    → calculates rank_improvement + NTILE + PERCENT_RANK
--   final SELECT    → aggregates by genre to show category-level effect
-- NOTE:    PERCENT_RANK() returns double precision in PostgreSQL.
--          Must cast to ::numeric before passing to ROUND().
-- =============================================================================

WITH grammy_winners AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) AS artist_clean,
        MIN(year) AS first_win_year,
        -- Map specific award names to broad genre categories
        -- using ILIKE for case-insensitive pattern matching
        CASE
            WHEN award ILIKE '%pop%'        THEN 'Pop'
            WHEN award ILIKE '%r&b%'        THEN 'R&B'
            WHEN award ILIKE '%rap%'
              OR award ILIKE '%hip hop%'    THEN 'Hip Hop'
            WHEN award ILIKE '%rock%'       THEN 'Rock'
            WHEN award ILIKE '%country%'    THEN 'Country'
            WHEN award ILIKE '%jazz%'       THEN 'Jazz'
            WHEN award ILIKE '%gospel%'
              OR award ILIKE '%christian%'  THEN 'Gospel'
            WHEN award ILIKE '%record%'
              OR award ILIKE '%album%'
              OR award ILIKE '%song%'       THEN 'General Field'
            ELSE 'Other'
        END AS genre_category
    FROM grammy_nominations
    WHERE winner = true
    AND artist IS NOT NULL
    AND artist != ''
    AND year <= 2021
    GROUP BY
        LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))),
        award
),
billboard_yearly AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(
            REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
            '[éèêë]', 'e', 'g'
        ))) AS artist_clean,
        EXTRACT(YEAR FROM chart_date)   AS chart_year,
        AVG(rank)                       AS avg_rank
    FROM billboard_hot100
    GROUP BY
        LOWER(TRIM(REGEXP_REPLACE(
            REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
            '[éèêë]', 'e', 'g'
        ))),
        EXTRACT(YEAR FROM chart_date)
),
pre_post AS (
    SELECT
        b.artist_clean,
        g.first_win_year,
        g.genre_category,
        b.chart_year,
        b.avg_rank,
        CASE
            WHEN b.chart_year BETWEEN g.first_win_year - 3 AND g.first_win_year - 1
                THEN 'pre_win'
            WHEN b.chart_year BETWEEN g.first_win_year + 1 AND g.first_win_year + 3
                THEN 'post_win'
        END AS period
    FROM billboard_yearly b
    JOIN grammy_winners g ON b.artist_clean = g.artist_clean
    WHERE b.chart_year BETWEEN g.first_win_year - 3 AND g.first_win_year + 3
    AND b.chart_year != g.first_win_year
),
aggregated AS (
    SELECT
        artist_clean,
        genre_category,
        first_win_year,
        ROUND(AVG(CASE WHEN period = 'pre_win'  THEN avg_rank END), 1) AS avg_rank_pre_win,
        ROUND(AVG(CASE WHEN period = 'post_win' THEN avg_rank END), 1) AS avg_rank_post_win
    FROM pre_post
    GROUP BY artist_clean, genre_category, first_win_year
),
improvements AS (
    SELECT
        artist_clean,
        genre_category,
        first_win_year,
        avg_rank_pre_win,
        avg_rank_post_win,
        ROUND(avg_rank_pre_win - avg_rank_post_win, 1)  AS rank_improvement,
        -- NTILE(4) buckets all artists into improvement quartiles:
        --   1 = top 25% improvers (strongest Grammy Effect)
        --   4 = bottom 25% (biggest decliners after winning)
        NTILE(4) OVER (
            ORDER BY avg_rank_pre_win - avg_rank_post_win DESC
        )                                               AS improvement_quartile,
        -- PERCENT_RANK() shows relative standing as a 0-1 value
        -- Cast to ::numeric required for ROUND() in PostgreSQL
        ROUND(PERCENT_RANK() OVER (
            ORDER BY avg_rank_pre_win - avg_rank_post_win
        )::numeric, 3)                                  AS improvement_percentile
    FROM aggregated
    WHERE avg_rank_pre_win IS NOT NULL
    AND avg_rank_post_win IS NOT NULL
)
SELECT
    genre_category,
    COUNT(*)                                AS total_artists,
    ROUND(AVG(rank_improvement), 1)         AS avg_rank_improvement,
    SUM(CASE WHEN rank_improvement > 0
        THEN 1 ELSE 0 END)                  AS improved_count,
    SUM(CASE WHEN rank_improvement < 0
        THEN 1 ELSE 0 END)                  AS declined_count,
    ROUND(AVG(improvement_percentile), 3)   AS avg_percentile
FROM improvements
GROUP BY genre_category
ORDER BY avg_rank_improvement DESC;

-- Key findings:
--   Pop:          avg +6.6, 65% improved — strongest Grammy Effect by far
--                 Grammy validation most directly boosts mainstream Pop careers
--   General Field: avg +4.9, 60% improved — Record/Album/Song of the Year
--                 winners see strong boosts due to massive ceremony visibility
--   Rock:         avg +4.7, 58% improved — solid but weaker than Pop
--   Country:      avg +3.2, 52% improved — loyal fanbase less Grammy-driven
--   R&B:          avg +2.2, 46% improved — nearly even split, modest effect
--   Hip Hop:      avg +0.7, 51% improved — nearly no Grammy Effect
--                 Hip Hop chart success driven by cultural momentum and
--                 streaming virality rather than Grammy recognition
--   Gospel:       avg -13.2, only 33% improved — Grammy recognition does not
--                 translate to mainstream Hot 100 chart activity for Gospel
--                 artists whose audience is niche and loyal regardless
--
-- CONCLUSION: The Grammy Effect is not equal across genres. Pop category
--   winners see the strongest and most consistent commercial boost.
--   Hip Hop and Gospel winners see little to no Billboard benefit,
--   suggesting Grammy recognition carries less commercial weight in
--   those genres where audience behavior is driven by different factors.
--
-- TABLEAU NOTE: Key visualizations for this section:
--   1. Horizontal bar chart: avg_rank_improvement by genre_category
--      colored by improvement direction (positive = green, negative = red)
--   2. Stacked bar chart: improved_count vs declined_count per genre
--      showing the win/loss ratio visually per category
--   3. Scatter plot: individual artists plotted by improvement_percentile
--      colored by genre_category — shows distribution within each genre