-- =============================================================================
-- PROJECT:  The Grammy Effect - EDA on Billboard Chart Performance
-- FILE:     sql/schema/create_tables.sql
-- AUTHOR:   Jishnu Kandala
-- PURPOSE:  Creates the two core tables for this project and documents
--           the data loading process from raw Kaggle CSVs
-- =============================================================================


-- =============================================================================
-- TABLE 1: billboard_hot100
-- Source: https://www.kaggle.com/datasets/dhruvildave/billboard-the-hot-100-songs
-- Description: Weekly Billboard Hot 100 chart data from 1958 to 2021
--              330,087 rows covering every weekly chart entry
-- Notes:
--   - Column names renamed from hyphenated originals (e.g. last-week → last_week)
--     because PostgreSQL does not handle hyphens in column names cleanly
--   - chart_date stored as DATE (not VARCHAR) so PostgreSQL can perform
--     real date arithmetic for pre/post Grammy year comparisons
--   - id is SERIAL (auto-generated) and excluded from the COPY import
-- =============================================================================

CREATE TABLE billboard_hot100 (
    id              SERIAL PRIMARY KEY,
    chart_date      DATE,           -- week the chart was published
    rank            INT,            -- chart position that week (1-100)
    song            VARCHAR(255),   -- song title
    artist          VARCHAR(255),   -- artist name
    last_week       INT,            -- chart position the previous week (NULL if new entry)
    peak_rank       INT,            -- highest chart position the song has reached
    weeks_on_board  INT             -- total weeks the song has appeared on the chart
);


-- Load Billboard data from CSV
-- Note: id is excluded so PostgreSQL auto-generates it
-- Note: column order must match the CSV column order exactly

COPY billboard_hot100(chart_date, rank, song, artist, last_week, peak_rank, weeks_on_board)
FROM '/Users/jishnukandala/Desktop/grammy-effect-exploratory-data-analysis/data/charts.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- Result: 330,087 rows loaded successfully


-- =============================================================================
-- TABLE 2: grammy_nominations
-- Source: https://www.kaggle.com/datasets/johnpendenque/grammy-winners-and-nominees-from-1965-to-2024
-- Description: Grammy Award nominees and winners from 1958 to 2024
--              25,535 rows covering all categories and years
-- Notes:
--   - artist_link and url columns from the original CSV were intentionally
--     dropped as they are web paths with no analytical value for this project
--   - To handle the dropped middle columns during import, artist_link and url
--     were temporarily added, data was loaded, then both columns were dropped
--   - winner stored as BOOLEAN (True/False) for clean filtering in queries
--   - producers stored as TEXT (not VARCHAR) because the field can be very
--     long when multiple producers are credited
-- =============================================================================

CREATE TABLE grammy_nominations (
    id              SERIAL PRIMARY KEY,
    annual_edition  INT,            -- Grammy ceremony number (1st, 2nd, etc.)
    year            INT,            -- year the music was released (eligibility year)
    award           VARCHAR(255),   -- Grammy category name
    artist          VARCHAR(255),   -- nominated artist
    producers       TEXT,           -- producers credited (can be multiple)
    song_or_album   VARCHAR(255),   -- nominated song or album title
    winner          BOOLEAN         -- TRUE if won, FALSE if nominated only
);


-- Step 1: Temporarily add dropped columns to match CSV column order exactly
-- (PostgreSQL COPY cannot skip middle columns during import)

ALTER TABLE grammy_nominations
ADD COLUMN artist_link VARCHAR(255),
ADD COLUMN url VARCHAR(255);


-- Step 2: Load Grammy data from CSV with all original columns accounted for

COPY grammy_nominations(annual_edition, year, award, artist, artist_link, producers, song_or_album, url, winner)
FROM '/Users/jishnukandala/Desktop/grammy-effect-exploratory-data-analysis/data/grammies_v4.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- Result: 25,535 rows loaded successfully


-- Step 3: Drop the temporary columns that have no analytical value

ALTER TABLE grammy_nominations
DROP COLUMN artist_link,
DROP COLUMN url;


-- =============================================================================
-- VERIFICATION QUERIES
-- Run after import to confirm row counts and data integrity
-- =============================================================================

SELECT COUNT(*) FROM billboard_hot100;
-- Expected: 330,087

SELECT COUNT(*) FROM grammy_nominations;
-- Expected: 25,535

SELECT * FROM billboard_hot100 LIMIT 5;
SELECT * FROM grammy_nominations LIMIT 5;