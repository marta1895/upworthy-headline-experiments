# Upworthy Headline Experiments
 
**Do A/B test winners really win?** A re-analysis of thousands of headline A/B tests run by Upworthy in 2013–2015: how many "winning" headlines were real improvements, how many were noise, and which headline features are associated with higher click-through rate (CTR).
 
> Status: in progress. Phase 1 (data understanding) complete.
 
## Dataset
 
[The Upworthy Research Archive](https://osf.io/jd64p/): randomized headline tests run by Upworthy from January 2013 to April 2015.
 
- **Exploratory set** (used for all exploration): 22,666 packages (variants) from 4,873 tests.
- **Confirmatory set**: kept unopened until the confirmatory step (Phase 6).
- One row = one **package** (variant): a headline + image version of a story, randomly shown to visitors as part of a test.
Citation: Matias, J. N., Munger, K., Aubin Le Quere, M., & Ebersole, C. (2021). *The Upworthy Research Archive, a time series of 32,487 experiments in U.S. media.* Scientific Data, 8, 195. [doi:10.1038/s41597-021-00934-7](https://doi.org/10.1038/s41597-021-00934-7)
 
License: data published under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Raw data files are not included in this repository; see [How to reproduce](#how-to-reproduce).
 
## Data dictionary
 
Raw data is loaded into PostgreSQL as text (`upworthy.raw_packages_explore`) and cast to the types below during cleaning. Meanings follow the [archive documentation](https://upworthy.natematias.com/about-the-archive); notes are findings from Phase 1 (`sql/02_data_understanding.sql`).
 
| Column | Type after cleaning | Meaning | Note |
| --- | --- | --- | --- |
| `row_idx` | integer | Unnamed index column in the source file | Not used in analysis |
| `clickability_test_id` | text | Test ID. Viewers were randomly assigned to packages sharing the same test ID | 4,873 tests; 0 empty |
| `created_at` | timestamp | When the package was created (timezone unknown) | 2013-01-26 to 2015-04-29; 0 empty |
| `updated_at` | timestamp | Last time the package was updated in Upworthy's system | Not used in analysis |
| `test_week` | integer | Week the package was created (YYYYWW, weeks start on Sunday; days before the first Sunday of the year are week 00), built by the archive creators for stratified sampling | 0 empty |
| `headline` | text | The headline being tested | 0 empty |
| `excerpt` | text | The article excerpt | 2,417 empty (10.7%); empty treated as a real variant ("no excerpt shown") |
| `lede` | text | The story's opening sentence or paragraph | 12 empty (0.05%); not used |
| `slug` | text | Internal name used in the web address | Not used |
| `eyecatcher_id` | text | Image ID. Image files are not available; packages with the same image share an ID | 22 empty (0.1%), all in 5 tests; those tests are excluded from headline-only analysis |
| `share_text` | text | Summary shown when shared on social media; not shown in tests | 19,458 empty (85.8%); not used |
| `square` | text | Part of the social media sharing suggestion, with `share_text`; not shown in tests | 15,220 empty (67.2%); not used |
| `impressions` | integer | Number of viewers assigned to the package | Median 3,122 per variant; min 13, max 25,314 |
| `clicks` | integer | Number of viewers who clicked the package | Median 42 per variant; CTR = clicks / impressions |
| `significance` | numeric | Score shown to editors. **Not** a statistical significance estimate; how it was calculated is unknown | 0–100, median 25.7; not used as evidence |
| `first_place` | boolean | Shown to editors with `significance` to help choose a package | 4,823 variants True |
| `winner` | boolean | Whether editors selected the package for use on the site after the test | 1,152 variants True; 283 winners were not `first_place` |
 
## Known data issues
 
- **Randomization problem, June 25, 2013 – January 10, 2014.** The archive team reported systematic randomization problems in about 22% of tests in this window and recommends that confirmatory research avoid it. The exploratory file used here (dated 2020) has no flag column for this, so affected tests are flagged by date during cleaning (Phase 2).
- **`significance` is not a statistical measure**, so this project computes its own p-values per test instead of relying on it.
## Repository structure
 
```
sql/
├── 01_load.sql                 # create raw table, import, post-load validation
└── 02_data_understanding.sql   # Phase 1: data understanding
```
 
## How to reproduce
 
1. Download `upworthy-archive-exploratory-packages-03.12.2020.csv` from [OSF](https://osf.io/jd64p/) into `data/exploratory/` (add `.csv` to the file name if missing).
2. Create a PostgreSQL database `upworthy` and run the `CREATE SCHEMA` / `CREATE TABLE` statements in `sql/01_load.sql`.
3. Import the CSV into `upworthy.raw_packages_explore` (settings are documented in `sql/01_load.sql`).
4. Run `sql/02_data_understanding.sql`.
 