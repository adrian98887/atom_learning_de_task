-- SILVER 1 of 2: adrian_raszkiewicz.sittings
-- One row per finished, summative, fixed-question test. Nothing else gets through.
-- Source: de_raw.assessment_sittings.
-- Safe to re-run: the table is replaced with the same rows each time.

CREATE OR REPLACE TABLE adrian_raszkiewicz.sittings
PARTITION BY DATE(finished_at)  -- cheap to scan one day or one month at production size
CLUSTER BY pupil_id
AS
SELECT
  session_id,            -- one pupil sitting one test (unique)
  pupil_id,
  assessment_id,
  session_type,
  style,
  year_group_at_sitting,
  total_questions,       -- the number of questions in the test; used later as the 100% mark
  started_at,
  finished_at
FROM de_raw.assessment_sittings
WHERE session_type = 'summative_assessment'  -- drops mock_session and entrance_exam
  AND style = 'fixed_question'               -- drops survey (Wellbeing), which is not a score
  AND is_complete IS TRUE                    -- drops unfinished tests
  AND finished_at IS NOT NULL                -- a finished test always has a finish time
  AND is_deleted IS NOT TRUE                 -- all False today; keeps future deleted sittings out
;
