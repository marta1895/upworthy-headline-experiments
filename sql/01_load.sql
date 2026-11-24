-- 01_load.sql
-- Load the Upworthy exploratory packages file as raw text.
-- Every column is text on purpose: casting happens in 02_quality_checks.sql,
-- so bad values can be found with SQL instead of failing the import.

CREATE SCHEMA IF NOT EXISTS upworthy;

DROP TABLE IF EXISTS upworthy.raw_packages_explore;

CREATE TABLE upworthy.raw_packages_explore (
    row_idx               text,  -- unnamed index column from the source file
    created_at            text,
    updated_at            text,
    clickability_test_id  text,
    excerpt               text,
    headline              text,
    lede                  text,
    slug                  text,
    eyecatcher_id         text,
    impressions           text,
    clicks                text,
    significance          text,
    first_place           text,
    winner                text,
    share_text            text,
    square                text,
    test_week             text
);

-- Import done with the DBeaver Import Data wizard (not \copy):
--   Database: upworthy, table: upworthy.raw_packages_explore
--   Source: data/exploratory/upworthy-archive-exploratory-packages-03.12.2020.csv
--   Settings: CSV, UTF-8, header = top, delimiter = ',', quote = '"', escape = '"'
--   Unnamed first column mapped to row_idx

-- Check 1: total rows loaded (expected 22,666 per archive documentation)
SELECT COUNT(*) AS total_rows
FROM upworthy.raw_packages_explore;

-- Check 2: number of distinct tests (expected 4,873)
SELECT COUNT(DISTINCT clickability_test_id) AS total_tests
FROM upworthy.raw_packages_explore;

-- Check 3: rows where impressions or clicks are not whole numbers (expected 0)
SELECT COUNT(*) AS invalid_numeric_rows
FROM upworthy.raw_packages_explore
WHERE impressions !~ '^\d+$' OR clicks !~ '^\d+$';
