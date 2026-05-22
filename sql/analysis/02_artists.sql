-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/analysis/02_artists.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Artist layer — identifies which artists dominate Billboard
--           commercially vs Grammy critically. Uses RANK(), DENSE_RANK(),
--           and CASE WHEN to compare artist performance across both datasets.
-- NOTE:     All queries filter Grammy data to year <= 2021 to match the
--           Billboard dataset boundary (1958-2021). See 01_profile.sql
--           for full explanation of the analysis window decision.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Rank Billboard artists by total chart entries
-- PURPOSE: Identify the most commercially dominant artists on the Hot 100.
--          total_chart_entries counts every weekly appearance — an artist
--          with one song on the chart for 20 weeks contributes 20 entries.
--          This rewards sustained commercial presence over one-hit peaks.
-- CONCEPT: RANK() window function assigns position based on ORDER BY clause.
--          Ties receive the same rank and the next rank is skipped.
--          e.g. if two artists tie at rank 2, the next rank is 4 not 3.
-- =============================================================================

SELECT
    artist,
    COUNT(*) AS total_chart_entries,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS chart_rank
FROM billboard_hot100
GROUP BY artist
ORDER BY chart_rank
LIMIT 20;

-- Finding: Taylor Swift leads with 1,023 chart entries across 120 unique songs.
-- Kenny Chesney and Tim McGraw appear despite never reaching #1 —
-- showing consistent mid-chart longevity vs peak performance.


-- =============================================================================
-- QUERY 2: Rank Grammy artists by total wins
-- PURPOSE: Identify the most critically recognized artists by the Recording
--          Academy. Win rate (total_wins / total_nominations) reveals how
--          efficiently nominations convert to actual awards.
-- CONCEPT: DENSE_RANK() is used here instead of RANK() — ties receive the
--          same rank but the next rank is NOT skipped.
--          e.g. if two artists tie at rank 2, the next rank is 3 not 4.
--          DENSE_RANK() is preferred for Tableau visualizations as it
--          produces cleaner, gap-free ranking sequences.
-- NOTE:    CASE WHEN + SUM counts only winner = true rows.
--          COUNT(winner) would count all non-null rows regardless of value.
-- =============================================================================

SELECT
    artist,
    COUNT(*) AS total_nominations,
    SUM(CASE WHEN winner = true THEN 1 ELSE 0 END) AS total_wins,
    RANK() OVER (ORDER BY SUM(CASE WHEN winner = true THEN 1 ELSE 0 END) DESC) AS win_rank
FROM grammy_nominations
WHERE artist IS NOT NULL
AND artist != ''
AND year <= 2021
GROUP BY artist
ORDER BY win_rank
LIMIT 20;

-- Key findings:
--   Tony Bennett:    40 nominations, 19 wins = 47% win rate
--   Willie Nelson:   46 nominations,  8 wins = 17% win rate
--   U2:              35 nominations, 18 wins = 51% win rate
--   Adele:           13 nominations, 11 wins = 85% win rate (highest conversion)
--   Jimmy Sturr appears due to dominating the Best Polka Album category —
--   a reminder that genre filtering is essential in Section 5 analysis.


-- =============================================================================
-- QUERY 3: Billboard vs Grammy rank gap analysis
-- PURPOSE: The core artist layer insight — which artists are commercially
--          dominant but critically ignored (Billboard Dominant) and which
--          are critically acclaimed but rarely charted (Grammy Dominant)?
--          A large rank_gap signals a disconnect between commercial success
--          and critical recognition.
-- CONCEPT: Two subquery-wrapped CTEs collapse all artist name variations
--          before ranking. This prevents featured artist variants like
--          "Drake Featuring Rihanna" from inflating Drake's row count.
--          The CASE WHEN dominance_type column categorizes each artist
--          based on which rank is lower (lower rank = stronger performance).
-- NOTE:    WHERE b.total_chart_entries >= 200 filters to artists with
--          meaningful sustained Billboard presence to avoid skewing results
--          toward niche Grammy winners with minimal chart history.
-- =============================================================================

WITH billboard_ranked AS (
    SELECT
        artist_clean,
        SUM(chart_entries) AS total_chart_entries,
        DENSE_RANK() OVER (ORDER BY SUM(chart_entries) DESC) AS billboard_rank
    FROM (
        SELECT
            LOWER(TRIM(REGEXP_REPLACE(
                REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
                '[éèêë]', 'e', 'g'
            ))) AS artist_clean,
            COUNT(*) AS chart_entries
        FROM billboard_hot100
        GROUP BY artist
    ) cleaned
    GROUP BY artist_clean
),
grammy_ranked AS (
    SELECT
        artist_clean,
        SUM(total_wins) AS total_wins,
        DENSE_RANK() OVER (ORDER BY SUM(total_wins) DESC) AS grammy_rank
    FROM (
        SELECT
            LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) AS artist_clean,
            SUM(CASE WHEN winner = true THEN 1 ELSE 0 END) AS total_wins
        FROM grammy_nominations
        WHERE artist IS NOT NULL
        AND artist != ''
        AND year <= 2021
        GROUP BY artist
    ) cleaned
    GROUP BY artist_clean
)
SELECT
    b.artist_clean                                      AS artist,
    b.total_chart_entries,
    b.billboard_rank,
    g.total_wins,
    g.grammy_rank,
    ABS(b.billboard_rank - g.grammy_rank)              AS rank_gap,
    CASE
        WHEN b.billboard_rank < g.grammy_rank THEN 'Billboard Dominant'
        WHEN g.grammy_rank < b.billboard_rank THEN 'Grammy Dominant'
        ELSE 'Balanced'
    END                                                 AS dominance_type
FROM billboard_ranked b
JOIN grammy_ranked g ON b.artist_clean = g.artist_clean
WHERE b.total_chart_entries >= 200
ORDER BY g.total_wins DESC
LIMIT 20;

-- Key findings:
--   Taylor Swift: only Billboard Dominant artist in top 20 Grammy winners.
--                 2nd highest chart entries all time but 11th in Grammy wins.
--   Michael Jackson: most balanced — billboard_rank 19, grammy_rank 9.
--                    Only 10 rank gap despite massive scale on both sides.
--   U2, Aretha Franklin, Ray Charles, Stevie Wonder: Grammy Dominant —
--   massive critical recognition but Billboard ranks lower than expected
--   relative to their cultural stature.
--   Adele and Lady Gaga: fewer chart entries but strong Grammy wins —
--   Academy rewards quality and cultural impact over chart quantity.
--
-- TABLEAU NOTE: dominance_type is a strong visual dimension — use it to
--   color code artists on a scatter plot with billboard_rank on one axis
--   and grammy_rank on the other. Each dot = one artist, color = dominance.