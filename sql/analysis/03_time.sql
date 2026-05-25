-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/analysis/03_time.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Time layer — tracks how Billboard chart diversity and competitiveness
--           have changed across decades. Uses DATE_TRUNC() to aggregate weekly
--           data into years and decades, LAG() for year-over-year comparisons,
--           LEAD() to show forward-looking trends, and window frames for
--           rolling averages that smooth out year-to-year noise.
-- NOTE:     All queries use Billboard data only in this section as Grammy
--           data is not needed for time-based chart trend analysis.
--           Grammy data is reintroduced in 04_grammy_effect.sql.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Chart entries by decade
-- PURPOSE: Establish a high level view of chart activity across each decade.
--          Reveals how the music industry changed in terms of artist diversity
--          and song turnover from the 1950s through the 2020s.
-- CONCEPT: DATE_TRUNC('decade', chart_date) truncates each date to the first
--          day of its decade (e.g. 2021-08-15 → 2020-01-01). This collapses
--          all 3,301 weekly charts into 8 decade-level groups for analysis.
-- NOTE:    1950s and 2020s show significantly lower numbers because:
--          - Billboard Hot 100 launched in August 1958 (only ~2 years of 1950s data)
--          - Dataset ends November 2021 (only ~2 years of 2020s data)
--          These are not full decades and should not be compared directly
--          to complete decades in visualizations.
-- =============================================================================

SELECT
    DATE_TRUNC('decade', chart_date)    AS decade,
    COUNT(*)                            AS total_chart_entries,
    COUNT(DISTINCT artist)              AS unique_artists,
    COUNT(DISTINCT song)                AS unique_songs
FROM billboard_hot100
GROUP BY DATE_TRUNC('decade', chart_date)
ORDER BY decade;

-- Key findings:
--   1960s: most unique songs (6,219) — high turnover, songs left chart quickly
--   1980s-2000s: unique songs decline despite similar chart entry counts —
--   songs staying on chart longer as radio airplay extended hit lifespans
--   2010s: unique songs rise again (4,217) — streaming introduces more variety
--   The decline then recovery in unique songs mirrors the shift from
--   radio dominance to streaming as the primary consumption medium


-- =============================================================================
-- QUERY 2: Year over year change in unique artists using LAG()
-- PURPOSE: Track how artist diversity on the Hot 100 changed year by year.
--          yoy_change reveals which years saw the biggest surges or drops
--          in new artists breaking through to the chart.
-- CONCEPT: LAG(value, 1) OVER (ORDER BY ...) retrieves the value from the
--          previous row in the ordered result set. Subtracting LAG from the
--          current value gives year over year change without a self join.
--          The first row returns NULL for prev_year_artists since there is
--          no prior year to look back at.
-- =============================================================================

SELECT
    DATE_TRUNC('year', chart_date)      AS year,
    COUNT(DISTINCT artist)              AS unique_artists,
    LAG(COUNT(DISTINCT artist), 1) OVER (
        ORDER BY DATE_TRUNC('year', chart_date)
    )                                   AS prev_year_artists,
    COUNT(DISTINCT artist) - LAG(COUNT(DISTINCT artist), 1) OVER (
        ORDER BY DATE_TRUNC('year', chart_date)
    )                                   AS yoy_change
FROM billboard_hot100
GROUP BY DATE_TRUNC('year', chart_date)
ORDER BY year;

-- Key findings:
--   1999: largest single year drop (-88 unique artists)
--         Coincides with Napster launch and peak/collapse of boy band era.
--         Label revenue collapse reduced artist development budgets.
--   2017-2020: largest sustained surge in artist diversity
--         Streaming fully matured, lowering the barrier for independent
--         artists to reach the chart without major label backing.
--   2020: 465 unique artists despite COVID — streaming accelerated
--         during lockdowns, partially offsetting live music shutdown impact.
--   1980s: steady decline from 361 (1980) to 292 (1985)
--         Reflects major label consolidation reducing roster diversity.


-- =============================================================================
-- QUERY 3: 3 year rolling average of unique artists
-- PURPOSE: Smooth out year-to-year volatility in artist diversity to reveal
--          the underlying long term trend more clearly. Rolling averages are
--          a standard analytics technique for trend visualization.
-- CONCEPT: AVG() OVER (ORDER BY ... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
--          defines a sliding window of 3 rows — the current row and 2 rows
--          behind it. For each year the window averages:
--            - Current year
--            - 1 year prior
--            - 2 years prior
--          The window slides forward one row at a time producing a smoothed
--          value for each year. Early years (1958, 1959) average fewer rows
--          since there are no prior rows to look back at.
-- TABLEAU: Plot both unique_artists and rolling_3yr_avg as two lines on the
--          same axis. The raw line shows volatility, the rolling line shows
--          the true trend — a classic dual line chart pattern.
-- =============================================================================

SELECT
    DATE_TRUNC('year', chart_date)      AS year,
    COUNT(DISTINCT artist)              AS unique_artists,
    ROUND(AVG(COUNT(DISTINCT artist)) OVER (
        ORDER BY DATE_TRUNC('year', chart_date)
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1)                               AS rolling_3yr_avg
FROM billboard_hot100
GROUP BY DATE_TRUNC('year', chart_date)
ORDER BY year;

-- Key findings (rolling average removes noise and reveals):
--   1960s peak:       rolling avg ~400, most diverse era in chart history
--   1980s decline:    steady drop to ~300, label consolidation era
--   1990s-2000s flat: stabilizes ~300-330, CD era plateau
--   2017-2021 surge:  rolling avg climbs back to 440+, highest since 1960s
--                     driven by streaming democratizing chart access


-- =============================================================================
-- QUERY 4: Year over year average peak rank trajectory using LEAD()
-- PURPOSE: Track how competitive the top of the chart has become over time.
--          A lower avg_peak_rank means songs are peaking higher on average —
--          indicating fewer dominant acts monopolizing the top positions.
--          LEAD() shows the next year's value alongside the current year
--          for easy forward-looking comparison.
-- CONCEPT: LEAD(value, 1) OVER (ORDER BY ...) retrieves the value from the
--          NEXT row in the ordered result set — the opposite of LAG().
--          The last row returns NULL for next_year_avg_peak since there is
--          no future row to look ahead to.
-- NOTE:    Lower peak_rank = higher chart position (rank 1 is better than 50)
--          A declining avg_peak_rank means songs are peaking higher on average
-- =============================================================================

SELECT
    DATE_TRUNC('year', chart_date)          AS year,
    ROUND(AVG(peak_rank), 1)                AS avg_peak_rank,
    LEAD(ROUND(AVG(peak_rank), 1), 1) OVER (
        ORDER BY DATE_TRUNC('year', chart_date)
    )                                       AS next_year_avg_peak
FROM billboard_hot100
GROUP BY DATE_TRUNC('year', chart_date)
ORDER BY year;

-- Key findings:
--   1958-1972: avg peak rank rises from 40 to 48 — chart becoming more
--              competitive, harder to reach the top as more artists charted
--   1973-1984: sharp drop from 48 to 37 — album rock and disco era.
--              Fewer dominant artists monopolized top chart positions.
--   1985-2005: stabilizes around 36-40 — consistent competitive era
--   2017-2021: drops to 34-35, lowest in entire dataset history.
--              Streaming mega-hits (Drake, Post Malone, Taylor Swift)
--              dominating top positions more aggressively than any prior era.
--              The chart is becoming increasingly winner-take-all.