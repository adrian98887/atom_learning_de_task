-- GOLD: adrian_raszkiewicz.final_pupil_stats_score
-- One row per test. Each row adds that test onto the pupil's earlier tests in the same subject,
-- then turns the running percentage into an 80-120 SATs score.
-- To read a score on a past day, take each pupil and subject's latest row up to that day (see README).
-- Source: adrian_raszkiewicz.sitting_responses. Safe to re-run: the table is replaced with the same rows.

CREATE OR REPLACE TABLE adrian_raszkiewicz.final_pupil_stats_score
PARTITION BY DATE(finished_at)
CLUSTER BY pupil_id, subject_name
AS
WITH test AS (  -- one row per test
  SELECT
    session_id,
    pupil_id,
    MAX(subject_id) AS subject_id,           -- the same on every question of a test, so MAX just picks it up
    MAX(subject_name) AS subject_name,
    MAX(year_group_at_sitting) AS year_group_at_sitting,
    MAX(finished_at) AS finished_at,
    MAX(total_questions) AS questions,       -- blanks and missing rows stay in this total
    COUNT(*) AS rows_present,                -- question rows we actually have
    COUNTIF(is_correct) AS correct
  FROM adrian_raszkiewicz.sitting_responses
  GROUP BY session_id, pupil_id
),

running AS (  -- add each test onto the pupil's earlier tests in the same subject
  SELECT
    *,
    COUNT(*) OVER w AS sittings_to_date,     -- every "_to_date" column counts this test and all earlier ones
    SUM(correct) OVER w AS correct_to_date,
    SUM(questions) OVER w AS questions_to_date,
    100 * SUM(correct) OVER w / SUM(questions) OVER w AS pct  -- running percentage: right answers over all questions so far
  FROM test
  WINDOW w AS (
    PARTITION BY pupil_id, subject_name      -- a separate running total for each pupil and subject
    ORDER BY finished_at, session_id         -- oldest first; session_id settles ties so re-runs match
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  -- from this pupil's first test up to this one
  )
)

SELECT
  pupil_id,
  subject_id,
  subject_name,
  session_id,
  finished_at,
  year_group_at_sitting,
  questions AS questions_in_sitting,
  rows_present AS answer_rows_in_sitting,
  rows_present < questions AS has_missing_rows,  -- TRUE when some question rows were never recorded
  correct AS correct_in_sitting,
  sittings_to_date,
  correct_to_date,
  questions_to_date,
  ROUND(pct, 1) AS percentage_to_date,           -- for reading only; the score uses the exact pct
  IF(pct >= 5,                                   -- under 5% = no score (NULL)
     80 + (SELECT COUNT(*) FROM UNNEST([         -- the score is 80, plus 1 for each number below that pct has reached
       5, 7, 8, 10, 11, 13, 15, 17, 18, 20, 23, 25, 27, 30, 33, 37, 40, 43, 45, 49,   -- 81 to 100: the % needed for each score
       53, 55, 59, 63, 65, 69, 71, 73, 77, 79, 83, 84, 85, 87, 89, 91, 93, 93, 95, 98 -- 101 to 120 (93 twice: 117 is never given)
     ]) AS needed WHERE pct >= needed),
     NULL) AS sats_score                         -- 2026 KS2 tables, averaged (see README)
FROM running
;
