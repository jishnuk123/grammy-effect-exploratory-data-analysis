-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/analysis/04_grammy_effect.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  The core analysis — measures whether winning a Grammy Award
--           produces a measurable improvement in Billboard Hot 100 chart
--           performance. Compares each artist's average chart rank in the
--           3 years before their first Grammy win vs the 3 years after.
-- APPROACH: First Grammy win year is used as the benchmark (not all wins)
--           because it represents the clearest before/after inflection point.
--           Using all win years would create overlapping pre/post windows
--           that contradict each other for multi-time winners.
--           The win year itself is excluded from both windows as it reflects
--           a mix of pre and post Grammy momentum.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Artists with the biggest Billboard improvement after winning
-- PURPOSE: Identify which Grammy winners saw the largest boost in chart
--          performance after their first win. rank_improvement is calculated
--          as avg_rank_pre_win - avg_rank_post_win — a positive value means
--          the artist moved to a higher chart position (lower rank number)
--          after winning, indicating a genuine Grammy Effect.
-- STRUCTURE: Four chained CTEs:
--   grammy_winners  → finds each artist's first Grammy win year
--   billboard_yearly → calculates avg chart rank per artist per year
--   pre_post        → labels each year as pre_win or post_win relative
--                     to the first win year using BETWEEN
--   aggregated      → pivots pre/post into columns using AVG(CASE WHEN)
-- NOTE:    Lower rank number = higher chart position (rank 1 > rank 50)
--          A positive rank_improvement means the artist charted higher
--          on average after winning than before.
-- =============================================================================

WITH grammy_winners AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) AS artist_clean,
        MIN(year) AS first_win_year
    FROM grammy_nominations
    WHERE winner = true
    AND artist IS NOT NULL
    AND artist != ''
    AND year <= 2021
    GROUP BY LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g')))
),
billboard_yearly AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(
            REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
            '[éèêë]', 'e', 'g'
        ))) AS artist_clean,
        EXTRACT(YEAR FROM chart_date)   AS chart_year,
        AVG(rank)                       AS avg_rank,
        COUNT(DISTINCT song)            AS unique_songs
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
        b.chart_year,
        b.avg_rank,
        b.unique_songs,
        -- Label each chart year relative to the first Grammy win year
        -- pre_win:  3 years immediately before the win year
        -- post_win: 3 years immediately after the win year
        -- win year itself is excluded (handled by WHERE clause below)
        CASE
            WHEN b.chart_year BETWEEN g.first_win_year - 3 AND g.first_win_year - 1
                THEN 'pre_win'
            WHEN b.chart_year BETWEEN g.first_win_year + 1 AND g.first_win_year + 3
                THEN 'post_win'
        END AS period
    FROM billboard_yearly b
    JOIN grammy_winners g ON b.artist_clean = g.artist_clean
    WHERE b.chart_year BETWEEN g.first_win_year - 3 AND g.first_win_year + 3
    AND b.chart_year != g.first_win_year    -- exclude the win year itself
),
aggregated AS (
    SELECT
        artist_clean,
        first_win_year,
        -- Pivot pre and post averages into separate columns using CASE WHEN
        -- AVG(CASE WHEN period = 'pre_win' THEN avg_rank END) returns NULL
        -- for post_win rows and averages only the pre_win values
        ROUND(AVG(CASE WHEN period = 'pre_win'  THEN avg_rank END), 1) AS avg_rank_pre_win,
        ROUND(AVG(CASE WHEN period = 'post_win' THEN avg_rank END), 1) AS avg_rank_post_win
    FROM pre_post
    GROUP BY artist_clean, first_win_year
)
SELECT
    artist_clean                                            AS artist,
    first_win_year,
    avg_rank_pre_win,
    avg_rank_post_win,
    -- Positive value = improved (moved to higher chart position after win)
    -- Negative value = declined (moved to lower chart position after win)
    ROUND(avg_rank_pre_win - avg_rank_post_win, 1)         AS rank_improvement,
    CASE
        WHEN avg_rank_pre_win > avg_rank_post_win THEN 'Improved'
        WHEN avg_rank_pre_win < avg_rank_post_win THEN 'Declined'
        ELSE 'No Change'
    END                                                     AS grammy_effect
FROM aggregated
WHERE avg_rank_pre_win IS NOT NULL
AND avg_rank_post_win IS NOT NULL
ORDER BY rank_improvement DESC
LIMIT 20;

-- Key findings (top improvers):
--   Melissa Etheridge (1992): +61.7 rank improvement
--   Kenny Rogers (1977):      +61.5 rank improvement
--   Ray Charles (1960):       +56.8 rank improvement
--   Aretha Franklin (1967):   +50.9 rank improvement
--   Billie Eilish (2019):     +36.5 rank improvement
-- Pattern: mid-tier artists who were struggling before winning see the
-- biggest Grammy Effect. The win broke them through to mainstream audiences.


-- =============================================================================
-- QUERY 2: Artists with the biggest Billboard decline after winning
-- PURPOSE: Identify which Grammy winners saw chart performance worsen after
--          winning. A negative rank_improvement reveals artists who had
--          already peaked commercially before the Grammy recognized them.
--          This is just as analytically important as the improvers list —
--          it shows the Grammy Effect is not universal.
-- =============================================================================

WITH grammy_winners AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) AS artist_clean,
        MIN(year) AS first_win_year
    FROM grammy_nominations
    WHERE winner = true
    AND artist IS NOT NULL
    AND artist != ''
    AND year <= 2021
    GROUP BY LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g')))
),
billboard_yearly AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(
            REGEXP_REPLACE(artist, '\s+(Featuring|Feat\.|Ft\.|With|Duet).*$', '', 'i'),
            '[éèêë]', 'e', 'g'
        ))) AS artist_clean,
        EXTRACT(YEAR FROM chart_date)   AS chart_year,
        AVG(rank)                       AS avg_rank,
        COUNT(DISTINCT song)            AS unique_songs
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
        b.chart_year,
        b.avg_rank,
        b.unique_songs,
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
        first_win_year,
        ROUND(AVG(CASE WHEN period = 'pre_win'  THEN avg_rank END), 1) AS avg_rank_pre_win,
        ROUND(AVG(CASE WHEN period = 'post_win' THEN avg_rank END), 1) AS avg_rank_post_win
    FROM pre_post
    GROUP BY artist_clean, first_win_year
)
SELECT
    artist_clean                                            AS artist,
    first_win_year,
    avg_rank_pre_win,
    avg_rank_post_win,
    ROUND(avg_rank_pre_win - avg_rank_post_win, 1)         AS rank_improvement,
    CASE
        WHEN avg_rank_pre_win > avg_rank_post_win THEN 'Improved'
        WHEN avg_rank_pre_win < avg_rank_post_win THEN 'Declined'
        ELSE 'No Change'
    END                                                     AS grammy_effect
FROM aggregated
WHERE avg_rank_pre_win IS NOT NULL
AND avg_rank_post_win IS NOT NULL
ORDER BY rank_improvement ASC
LIMIT 20;

-- Key findings (biggest decliners):
--   Weezer (2008):          -54.4 — already peaking before win
--   Beck (1996):            -51.7 — pre-win avg rank of 33, already top tier
--   Kylie Minogue (2003):   -48.2 — same pattern
--   John Lennon (1981):     -31.1 — posthumous win, no new music possible
--   Christina Aguilera (2001): -31.0 — pre-win avg rank of 20, already dominant
-- Pattern: artists already in the top 20-30 before winning had nowhere
-- to go but down. The Grammy Effect is weakest for already-dominant artists.


-- =============================================================================
-- QUERY 3: Overall Grammy Effect summary
-- PURPOSE: The headline finding of the entire project. Aggregates across
--          all 191 qualifying artists to produce a single summary of whether
--          the Grammy Effect is real at a population level.
-- INSIGHT: The overall average improvement of 4.8 positions is modest but
--          the 57% vs 41% improved/declined split shows a consistent
--          directional effect. The average is suppressed by already-peaked
--          artists who decline after winning. The true Grammy Effect is
--          best seen in individual artist stories, not the population average.
-- =============================================================================

WITH grammy_winners AS (
    SELECT
        LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g'))) AS artist_clean,
        MIN(year) AS first_win_year
    FROM grammy_nominations
    WHERE winner = true
    AND artist IS NOT NULL
    AND artist != ''
    AND year <= 2021
    GROUP BY LOWER(TRIM(REGEXP_REPLACE(artist, '[éèêë]', 'e', 'g')))
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
        first_win_year,
        ROUND(AVG(CASE WHEN period = 'pre_win'  THEN avg_rank END), 1) AS avg_rank_pre_win,
        ROUND(AVG(CASE WHEN period = 'post_win' THEN avg_rank END), 1) AS avg_rank_post_win
    FROM pre_post
    GROUP BY artist_clean, first_win_year
)
SELECT
    COUNT(*)                                                    AS total_artists,
    SUM(CASE WHEN avg_rank_pre_win > avg_rank_post_win
        THEN 1 ELSE 0 END)                                      AS improved_count,
    SUM(CASE WHEN avg_rank_pre_win < avg_rank_post_win
        THEN 1 ELSE 0 END)                                      AS declined_count,
    ROUND(AVG(avg_rank_pre_win), 1)                             AS overall_avg_pre_win,
    ROUND(AVG(avg_rank_post_win), 1)                            AS overall_avg_post_win,
    ROUND(AVG(avg_rank_pre_win - avg_rank_post_win), 1)         AS avg_rank_improvement
FROM aggregated
WHERE avg_rank_pre_win IS NOT NULL
AND avg_rank_post_win IS NOT NULL;

-- HEADLINE FINDING:
--   Total artists analyzed:       191
--   Improved after winning:       110 (57%)
--   Declined after winning:        78 (41%)
--   Overall avg rank before win:   57.4
--   Overall avg rank after win:    52.7
--   Average rank improvement:       4.8 positions
--
-- CONCLUSION: The Grammy Effect is real but modest at the population level.
--   57% of Grammy winning artists improved their Billboard chart performance
--   in the 3 years following their first win, with an average improvement
--   of 4.8 rank positions. The effect is strongest for mid-tier artists
--   breaking through to mainstream audiences. Artists already dominating
--   the top 20 before winning show little to no improvement — and often
--   decline — as they had already reached their commercial peak before
--   the Grammy recognized them.
--
-- TABLEAU NOTE: Key visualizations for this section:
--   1. Bar chart: top 10 most improved vs top 10 most declined artists
--   2. Scatter plot: avg_rank_pre_win vs avg_rank_post_win, one dot per
--      artist, colored by grammy_effect (Improved/Declined)
--      — artists below the diagonal line improved after winning
--   3. KPI cards: 57% improved, 4.8 avg rank improvement, 191 artists