-- 0. Clean variants table: 11 used columns, types cast, empty image ids -> NULL
DROP TABLE IF EXISTS upworthy.variants;

CREATE TABLE upworthy.variants AS SELECT
	row_idx::integer AS variant_id,
	clickability_test_id,
	created_at::timestamp,
	headline,
	excerpt,
	NULLIF(eyecatcher_id, '') AS eyecatcher_id,
	impressions::integer,
	clicks::integer,
	winner::boolean,
	first_place::boolean,
	significance::numeric
FROM upworthy.raw_packages_explore;


-- 1. Check: invalid rows (missing test id, zero impressions, clicks > impressions)
SELECT 	
	COUNT(*) FILTER (WHERE clickability_test_id IS NULL OR clickability_test_id = '')      	AS empty_clickability_test_id,
	COUNT(*) FILTER (WHERE impressions = 0)      											AS zero_impressions,
	COUNT(*) FILTER (WHERE clicks > impressions) 											AS clicks_over_impressions
FROM upworthy.variants;
-- Result: 0 / 0 / 0. No invalid rows; no exclusions needed for these rules.

	
-- 2. Check: exact duplicate variants (same test, headline, excerpt and image)
SELECT 
	COUNT(*) AS n_duplicate_groups,
	SUM(n_copies) AS total_variants_rows,
	COUNT(DISTINCT clickability_test_id) AS n_tests
FROM (
	SELECT 
		COUNT(*) AS n_copies,
		clickability_test_id,
		headline,
		excerpt,
		eyecatcher_id
	FROM upworthy.variants
	GROUP BY clickability_test_id, headline, excerpt, eyecatcher_id
	HAVING COUNT(*) > 1
) t;
-- Result: 476 duplicate groups, 2,017 variants (8.9% of all), 463 tests (9.5%).
--   Duplicates likely differ only in columns not shown in tests (square, share_text).
--   Decision: keep. Each was randomized separately, so they are valid variants.


-- 3. Check: tests in the documented randomization-problem window (2013-06-25 to 2014-01-10)
--   Rule: flag the test if any of its variants was created in the window.
SELECT
	COUNT(DISTINCT clickability_test_id) AS n_tests
FROM upworthy.variants
WHERE DATE(created_at) BETWEEN '2013-06-25' AND '2014-01-10';
-- Result: 1,050 tests flagged (21.5% of 4,873).


-- 4. Check: tiny variants (very low impressions)
SELECT 	
	COUNT(*) FILTER (WHERE impressions < 100)	AS less_than_100_impressions,
	COUNT(*) FILTER (WHERE impressions < 500)	AS less_than_500_impressions,
	COUNT(*) FILTER (WHERE impressions < 1000)	AS less_than_1000_impressions
FROM upworthy.variants;
-- Result: < 100: 17 variants; < 500: 21; < 1,000: 41 (of 22,666; median 3,122).
--   Decision: flag tests containing a variant with < 100 impressions.
--   Unbalanced tests above that are caught by the SRM check in Phase 4.


-- 4a. Check: tests with at least one tiny variant (< 100 impressions)
SELECT
	COUNT(DISTINCT clickability_test_id) FILTER (WHERE impressions < 100) AS n_tests_tiny_variant
FROM upworthy.variants;
-- Result: 4 tests flagged (0.08% of 4,873). The 17 tiny variants are
--   concentrated in these few tests.