-- SILVER 2 of 2: adrian_raszkiewicz.sitting_responses
-- One row per question on each kept sitting, with the subject and topic of the question.
-- Source: adrian_raszkiewicz.sittings -> de_raw.responses -> de_raw.course_hierarchy.
-- Safe to re-run: the table is replaced with the same rows each time.

CREATE OR REPLACE TABLE adrian_raszkiewicz.sitting_responses
PARTITION BY DATE(finished_at)
CLUSTER BY pupil_id, session_id
AS
SELECT
  s.session_id,
  s.pupil_id,
  s.year_group_at_sitting,
  s.finished_at,
  s.total_questions,                       -- repeated on every row so the final table needs only this table
  r.question_id,
  MIN(r.question_number) AS question_number,
  LOGICAL_AND(r.is_correct) AS is_correct, -- if copies disagree, the answer counts as wrong
  LOGICAL_AND(r.is_no_attempt) AS is_no_attempt,  -- blank answer: still a wrong answer, still counted
  MAX(r.seconds_taken) AS seconds_taken,
  MAX(r.answered_at) AS answered_at,
  h.subject_id,
  h.subject_name,
  h.topic_id,
  h.subtopic_id,
  h.atom_id
FROM adrian_raszkiewicz.sittings AS s
JOIN de_raw.responses AS r                 -- attach answers to each sitting
  ON r.session_id = s.session_id           -- session_id only; answers with no kept sitting drop out here
LEFT JOIN de_raw.course_hierarchy AS h     -- find subjects and topics for each question; left join so a missing question is not silently lost
  ON h.question_id = r.question_id
GROUP BY                                   -- the same question can appear 2 to 5 times; collapse to one row
  s.session_id, s.pupil_id, s.year_group_at_sitting, s.finished_at, s.total_questions,
  r.question_id, h.subject_id, h.subject_name, h.topic_id, h.subtopic_id, h.atom_id
;
