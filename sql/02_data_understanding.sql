-- (1.) Empty values: for each column, how many rows are empty or null? The raw import keeps empties as '', not NULL, so I checked for both.
SELECT
	COUNT(*)                                                       							AS total_rows,
	COUNT(*) FILTER (WHERE created_at IS NULL OR created_at = '')      						AS empty_created_at,
	COUNT(*) FILTER (WHERE updated_at IS NULL OR updated_at = '')      						AS empty_updated_at,
	COUNT(*) FILTER (WHERE clickability_test_id IS NULL OR clickability_test_id = '')      	AS empty_clickability_test_id,
	COUNT(*) FILTER (WHERE excerpt IS NULL OR excerpt = '')             					AS empty_excerpt,
	COUNT(*) FILTER (WHERE headline IS NULL OR headline = '')      							AS empty_headline,
	COUNT(*) FILTER (WHERE lede IS NULL OR lede = '')                						AS empty_lede,
	COUNT(*) FILTER (WHERE slug IS NULL OR slug = '')                						AS empty_slug,
	COUNT(*) FILTER (WHERE eyecatcher_id IS NULL OR eyecatcher_id = '')       				AS empty_image,
	COUNT(*) FILTER (WHERE impressions IS NULL OR impressions = '')       					AS empty_impressions,
	COUNT(*) FILTER (WHERE clicks IS NULL OR clicks = '')       							AS empty_clicks,
	COUNT(*) FILTER (WHERE significance IS NULL OR significance = '')       				AS empty_significance,
	COUNT(*) FILTER (WHERE first_place IS NULL OR first_place = '')       					AS empty_first_place,
	COUNT(*) FILTER (WHERE winner IS NULL OR winner = '')              						AS empty_winner,
	COUNT(*) FILTER (WHERE share_text IS NULL OR share_text = '')          					AS empty_share_text,
	COUNT(*) FILTER (WHERE square IS NULL OR square = '')             	 					AS empty_square,
	COUNT(*) FILTER (WHERE test_week IS NULL OR test_week = '')              				AS empty_test_week
FROM upworthy.raw_packages_explore;
-- Result:
-- Total rows: 22,666.
-- All columns needed for the A/B analysis are complete (0 empty):
--   clickability_test_id, created_at, updated_at, headline, slug, impressions,
--   clicks, significance, first_place, winner, test_week.
-- Columns with empty values (not used in the analysis, kept in raw table):
--   share_text  19,458 (85.8%)
--   square      15,220 (67.2%)
--   excerpt      2,417 (10.7%)
--   lede            12 (0.05%)
-- eyecatcher_id (image): 22 empty (0.1%). Affects Phase 6 only: tests with a
--   missing image id cannot be confirmed as headline-only, so they will be
--   excluded from the headline-only subset (not from the whole project).
-- Missing images per test: resolved in 6a. Still open: check for space-only values.


-- (2.) Company result fields: what distinct values do winner, first_place and significance contain, and how often does each appear?
SELECT
	winner,
	first_place,
	COUNT(*) AS cnt
FROM upworthy.raw_packages_explore
GROUP BY winner, first_place
ORDER BY cnt DESC;
-- Result: only True/False values (counts sum to 22,666).
--   1,152 winner variants; 4,823 first_place variants.
--   283 variants are winner = True but first_place = False.
--   Largest group: winner = False and first_place = False, 17,560 variants.


-- 2a. Check: significance contains only valid numbers (digits, optional decimal part)
SELECT
	COUNT(*)
FROM upworthy.raw_packages_explore
WHERE significance !~ '^\d+(\.\d+)?$';
-- Result: 0 invalid values out of 22,666. Safe to cast to numeric.


-- 2b. Check: significance range and scale
SELECT
	MIN(significance::numeric) AS min_significance,
	MAX(significance::numeric) AS max_significance,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY significance::numeric) AS median_significance,
	COUNT(*) FILTER (WHERE significance::numeric = 0) AS zero_significance_cnt,
	COUNT(*) FILTER (WHERE significance::numeric = 100) AS hundred_significance_cnt
FROM upworthy.raw_packages_explore;
-- Result: scale is 0-100 (min 0, max 100, median 25.7).
--   Pile-ups at both edges: 2,270 rows = 0 (10.0%), 4,774 rows = 100 (21.1%).
--   Per archive documentation, significance is NOT a statistical significance
--   estimate; how it was calculated is unknown. It was shown to editors.
--   Note: 4,774 rows at 100 is close to the 4,823 first_place variants (see 2c).


-- 2c. Check: is significance per variant or per test?
SELECT n_significance, COUNT(*) AS cnt
FROM (SELECT clickability_test_id, COUNT(DISTINCT significance::numeric) AS n_significance
  		FROM upworthy.raw_packages_explore
  		GROUP BY clickability_test_id
 ) t
 GROUP BY n_significance
 ORDER BY n_significance;
-- Result: per variant. Distinct significance values per test closely follow the
--   number of variants (e.g. 2,343 tests with 4 distinct values vs 2,516 tests with
--   4 variants); small gap = ties within a test.
--   100 tests have a single significance value shared by all variants -> check which value.


-- 2d. Check: significance for winner vs non-winner variants
SELECT
	winner,
	COUNT(*) AS n_variants,
	MIN(significance::numeric) AS min_significance,
	MAX(significance::numeric) AS max_significance,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY significance::numeric) AS median_significance
FROM upworthy.raw_packages_explore
GROUP BY winner;
-- Result: winners (1,152 variants) median 100, but range 0-100 -> no strict cutoff rule.
--   Non-winners (21,514 variants) median 22.4, also reach 100.
--   Some winners declared with significance as low as 0 -> investigate.


-- 2e. Check: significance bands among declared winners (1,152 variants)
SELECT
	COUNT(*) FILTER(WHERE significance::numeric = 0) AS cnt_0_significance,
	COUNT(*) FILTER(WHERE significance::numeric > 0 AND significance::numeric < 50) AS cnt_0_50_significance,
	COUNT(*) FILTER(WHERE significance::numeric >= 50 AND significance::numeric < 95) AS cnt_50_95_significance,
	COUNT(*) FILTER(WHERE significance::numeric >= 95) AS cnt_95_significance
FROM upworthy.raw_packages_explore
WHERE winner = 'True';
-- Result: 892 (77.4%) at 95+; 159 (13.8%) 50-95; 78 (6.8%) 0-50; 23 (2.0%) at 0.
--   Most winners had a high significance score, but 260 (22.6%) were selected
--   below 95. Since significance is not a statistical measure, winners are
--   re-tested with our own p-values in Phase 4 (input for H2).


-- 2f. Significance of winners that were NOT first place (283 variants)
-- Question: were these "mismatch" winners declared with weaker evidence than
--   winners overall (77.4% at 95+, see 2e)?
SELECT
    COUNT(*) FILTER(WHERE significance::numeric = 0) AS cnt_0_significance,
    COUNT(*) FILTER(WHERE significance::numeric > 0 AND significance::numeric < 50) AS cnt_0_50_significance,
    COUNT(*) FILTER(WHERE significance::numeric >= 50 AND significance::numeric < 95) AS cnt_50_95_significance,
    COUNT(*) FILTER(WHERE significance::numeric >= 95) AS cnt_95_significance
FROM upworthy.raw_packages_explore
WHERE winner = 'True' AND first_place = 'False';
-- Result: 283 mismatch winners: 31 (11.0%) at 95+; 159 (56.2%) 50-95;
--   78 (27.6%) 0-50; 15 (5.3%) at 0. Compare 2e: 77.4% of all winners at 95+.
--   The 159 and 78 match 2e exactly -> almost all sub-95 winners are mismatch
--   winners; first-place winners are nearly all 95+ (861 of 869).
--   winner = editors' choice, so editors sometimes picked a non-first variant
--   with a low significance score.



-- (3.) Variants per test: how many tests have 2 variants, 3 variants, and so on?
SELECT n_variants, COUNT(*) AS n_tests
FROM (SELECT clickability_test_id, COUNT(*) AS n_variants
  		FROM upworthy.raw_packages_explore
  		GROUP BY clickability_test_id
 ) t
 GROUP BY n_variants
 ORDER BY n_variants;
-- Result: Upworthy tests are mostly multi-variant (median 4 variants; 2,516 of
--   4,873 tests have 4). Only 127 tests (2.6%) are two-variant A/B tests,
--   so multiple-comparison effects are central to this analysis.



-- (4.) Variant size: impressions and clicks per variant (all 22,666 variants)
SELECT
    MIN(impressions::int)                                         AS impressions_min,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY impressions::int) AS impressions_p10,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY impressions::int) AS impressions_p50,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY impressions::int) AS impressions_p90,
    MAX(impressions::int)                                         AS impressions_max,
    MIN(clicks::int)                                              AS clicks_min,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY clicks::int)      AS clicks_p10,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY clicks::int)      AS clicks_p50,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY clicks::int)      AS clicks_p90,
    MAX(clicks::int)                                              AS clicks_max
FROM upworthy.raw_packages_explore;
-- Result: median variant = 3,122 impressions, 42 clicks (CTR ~1.35%).
--   p10-p90 impressions: 2,142-5,405 (fairly standardized traffic per variant).
--   Min 13 impressions, max 25,314; clicks 0-975.
--   Next: count variants with very low impressions (e.g. < 1,000).


-- 4a. Variant size by number of variants in the test
WITH v AS (
    SELECT
        impressions::int AS impressions,
        clicks::int      AS clicks,
        COUNT(*) OVER (PARTITION BY clickability_test_id) AS n_variants
    FROM upworthy.raw_packages_explore
)
SELECT
    n_variants,
    COUNT(*)                                                      AS n_variant_rows,
    MIN(impressions)                                              AS impressions_min,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY impressions)      AS impressions_p10,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY impressions)      AS impressions_p50,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY impressions)      AS impressions_p90,
    MAX(impressions)                                              AS impressions_max,
    MIN(clicks)                                                   AS clicks_min,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY clicks)           AS clicks_p10,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY clicks)           AS clicks_p50,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY clicks)           AS clicks_p90,
    MAX(clicks)                                                   AS clicks_max
FROM v
GROUP BY n_variants
ORDER BY n_variants;
-- Result: impressions per variant roughly constant (~3,100-3,400) for tests
--   with 4-8 variants; higher in 2-variant tests (4,589), lower for 10+ (~2,200,
--   small groups). Each variant got a similar traffic budget; more variants did
--   not mean less traffic per variant.
--   Note: median clicks drop as variants increase -> check CTR by test size (4c).


-- 4b. CTR distribution per variant (all 22,666 variants), in %
SELECT
    MIN(100.0 * clicks::numeric / impressions::numeric)                                        AS min_ctr,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY 100.0 * clicks::numeric / impressions::numeric) AS p10_ctr,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 100.0 * clicks::numeric / impressions::numeric) AS p50_ctr,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY 100.0 * clicks::numeric / impressions::numeric) AS p90_ctr,
    MAX(100.0 * clicks::numeric / impressions::numeric)                                        AS max_ctr,
    100.0 * SUM(clicks::numeric) / SUM(impressions::numeric)                                   AS pooled_ctr
FROM upworthy.raw_packages_explore;
-- Result: per-variant CTR median 1.25% (p10 0.45%, p90 3.08%), range 0-13.6%.
--   Pooled CTR 1.52% > median -> right-skewed; high-CTR variants pull the total up.
--   Some variants have 0% CTR -> check in Phase 2.


-- 4c. CTR distribution by number of variants in the test, in %
WITH v AS (
    SELECT
        impressions::numeric AS impressions,
        clicks::numeric      AS clicks,
        COUNT(*) OVER (PARTITION BY clickability_test_id) AS n_variants
    FROM upworthy.raw_packages_explore
)
SELECT
    n_variants,
    COUNT(*)                                                                   AS n_variant_rows,
    MIN(100.0 * clicks / impressions)                                          AS min_ctr,
    PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY 100.0 * clicks / impressions)  AS p10_ctr,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 100.0 * clicks / impressions)  AS p50_ctr,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY 100.0 * clicks / impressions)  AS p90_ctr,
    MAX(100.0 * clicks / impressions)                                          AS max_ctr,
    100.0 * SUM(clicks) / SUM(impressions)                                     AS pooled_ctr
FROM v
GROUP BY n_variants
ORDER BY n_variants;
-- Result: bigger tests have lower CTR. Median ~1.5% with 2-4 variants,
--   ~1.0% with 6-8 variants. Cause unknown -> check in Phase 7.
--   (12 and 14 variants = 1 test each, ignored.)



-- (5.) Date range: what are the earliest and latest created_at values?
SELECT
	MIN(created_at::timestamp) AS min_created_at,
	MAX(created_at::timestamp) AS max_created_at
FROM upworthy.raw_packages_explore;
-- Result: tests run from 2013-01-26 to 2015-04-29 (~27 months).


-- 5a. Tests per month: how many tests started each month?
--   Each test counted once, by its earliest created_at.
SELECT COUNT(*) AS n_tests, DATE_TRUNC('month', min_created_at::timestamp) AS min_month
FROM (SELECT clickability_test_id, MIN(created_at) AS min_created_at
          FROM upworthy.raw_packages_explore
          GROUP BY clickability_test_id
 ) t
GROUP BY min_month
ORDER BY min_month;
-- Result: 28 months, 4,873 tests (sum checked).
--   2013: 1,361 tests. Slow start (Jan 2, Feb 26), ~150-180/month from June.
--   2014: 2,849 tests. Growth from June, peak Sep-Oct (353, 381).
--   2015: 663 tests in 4 months, falling to ~150/month.
--   Jan 2013 and Apr 2015 are partial months.
--   Note: the exploratory set is a random sample stratified by week, so the
--   monthly shape should reflect all Upworthy tests, at a smaller scale.


-- 5b. test_week format: does test_week match the week of created_at?
--   One row per distinct date (time removed) to compare different days.
SELECT DISTINCT
	DATE(created_at::timestamp) AS created_date,
	test_week
FROM upworthy.raw_packages_explore
LIMIT 20;
-- Result: test_week = YYYYWW, weeks start on Sunday; days before the first Sunday
--   of the year are week 00 (e.g. 2014-01-03 -> 201400, 2014-06-08 (Sunday) -> 201423).
--   All 20 sampled dates match this rule; ISO weeks (Monday start, no week 00) do not.
--   created_at timezone is unknown, so dates near midnight may shift a week (minor).



-- (6.) Headline vs image: what changes between variants inside a test?
--   Per test: distinct headlines and distinct images (empty eyecatcher_id ignored).
WITH cte AS (
	SELECT
		clickability_test_id,
		COUNT(DISTINCT NULLIF(eyecatcher_id, '')) AS distinct_images,
		COUNT(DISTINCT headline) AS distinct_headlines
	FROM upworthy.raw_packages_explore
	GROUP BY clickability_test_id
)
SELECT
COUNT(CASE WHEN distinct_headlines >= 2 AND distinct_images = 1 THEN 1 END) AS headline_only,
COUNT(CASE WHEN distinct_headlines = 1 AND distinct_images >= 2 THEN 1 END) AS image_only,
COUNT(CASE WHEN distinct_headlines >= 2 AND distinct_images >= 2 THEN 1 END) AS both_changed,
COUNT(CASE WHEN distinct_headlines = 1 AND distinct_images = 1 THEN 1 END) AS nothing_changed
FROM cte;
-- Result (4,868 of 4,873 tests classified):
--   headline-only    2,304 (47.3%)  -> base for Phase 6
--   image-only       1,426 (29.3%)
--   nothing changed    838 (17.2%)  -> headline and image identical; see 6b
--   both changed       300 (6.2%)
--   5 tests not classified: all variants have an empty image id.
-- Empty-image flag: resolved in 6a.


-- 6a. Empty-image check: are the 22 empty-image variants only in the 5 fully
--   empty tests, or also in tests that have a real image?
WITH cte AS (
    SELECT
        clickability_test_id,
        COUNT(DISTINCT NULLIF(eyecatcher_id, ''))                         AS distinct_images,
        COUNT(*) FILTER (WHERE eyecatcher_id IS NULL OR eyecatcher_id = '') AS empty_images
    FROM upworthy.raw_packages_explore
    GROUP BY clickability_test_id
)
SELECT
    COUNT(*) FILTER (WHERE empty_images > 0)                         AS tests_with_empty_image,
    COUNT(*) FILTER (WHERE empty_images > 0 AND distinct_images = 0) AS tests_all_empty,
    COUNT(*) FILTER (WHERE empty_images > 0 AND distinct_images >= 1) AS tests_mixed
FROM cte;
-- Result: all 22 empty-image variants are in 5 tests where every variant
--   has an empty image (tests_mixed = 0). No partially empty tests, so the
--   headline-only count of 2,304 is final. The 5 tests stay unclassified
--   and are excluded from Phase 6.


-- 6b. What differs in "nothing changed" tests?
-- Step 1: list tests where headline and image id are the same across all variants
WITH cte AS (
    SELECT
        clickability_test_id,
        COUNT(DISTINCT NULLIF(eyecatcher_id, '')) AS distinct_images,
        COUNT(DISTINCT headline)                  AS distinct_headlines
    FROM upworthy.raw_packages_explore
    GROUP BY clickability_test_id
)
SELECT clickability_test_id
FROM cte
WHERE distinct_headlines = 1 AND distinct_images = 1;
-- Step 2: inspect all variants of three tests picked from that list
SELECT *
FROM upworthy.raw_packages_explore
WHERE clickability_test_id IN (
    '5143606d220cb80002000643',
    '51890a6af651b4001500b412',
    '5198d88d209b7000160042f0'
);
-- Result: 3 "nothing changed" tests inspected:
--   5143606d220cb80002000643: same eyecatcher_id, but square (image file) differs
--     -> actually an image test.
--   51890a6af651b4001500b412, 5198d88d209b7000160042f0: same headline, image id
--     and square; excerpt differs -> excerpt tests.
-- Implication: eyecatcher_id alone may not identify the image (square may), and
--   excerpt can also vary. The headline-only definition must be re-checked
--   against square and excerpt (see 6c).


-- 6c. Re-check headline-only tests: did square (image file) or excerpt also change?
--   square: '' treated as missing (NULLIF), since 67% of rows are empty.
--   excerpt: '' counted as a real value ("no excerpt shown" is a real variant).
WITH cte AS (
    SELECT
        clickability_test_id,
        COUNT(DISTINCT NULLIF(eyecatcher_id, '')) AS distinct_images,
        COUNT(DISTINCT headline)                  AS distinct_headlines,
        COUNT(DISTINCT NULLIF(square, ''))        AS distinct_square,
        COUNT(DISTINCT excerpt)                   AS distinct_excerpt
    FROM upworthy.raw_packages_explore
    GROUP BY clickability_test_id
)
SELECT
    COUNT(*)                                                   AS headline_only_tests,
    COUNT(*) FILTER (WHERE distinct_square > 1)                AS square_changed,
    COUNT(*) FILTER (WHERE distinct_excerpt > 1)               AS excerpt_changed,
    -- Note: distinct_square <= 1 also includes tests where square is empty for all
    -- variants (count 0); without image files we can't show the image changed.
    COUNT(*) FILTER (WHERE distinct_square <= 1
                       AND distinct_excerpt = 1)               AS truly_headline_only
FROM cte
-- Keep only headline-only tests (2+ distinct headlines, 1 image id), so all
-- four counts are within the 2,304 tests from question 6, not all 4,873.
WHERE distinct_headlines >= 2
  AND distinct_images = 1;
-- Result: of 2,304 headline-only tests:
--   square changed: 0 -> eyecatcher_id is reliable within this group.
--   excerpt changed: 260 (11.3%) -> CTR differences may come from the excerpt.
--   truly headline-only (same image, same excerpt): 2,044 (88.7%).
-- Decision: Phase 6 uses the 2,044 truly headline-only tests.