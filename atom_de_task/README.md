# Pupil SATs scores (80-120)

One 80-120 SATs-style score per pupil and subject, that can be read as it stood on any past day.

## How to run it

- **Bronze:** the four raw `de_raw` tables, untouched. `de_raw.pupils` is not used, as it adds nothing new.
- **Silver:** `adrian_raszkiewicz.sittings` (one row per finished, summative, fixed-question test) and `adrian_raszkiewicz.sitting_responses` (one row per question on those tests, with the subject).
- **Gold:** `adrian_raszkiewicz.final_pupil_stats_score`, one row per test with the pupil's running percentage for the subject and the 80-120 score.

Run in BigQuery, in this order. Each file is one `CREATE OR REPLACE TABLE`, so a re-run gives the same rows.

1. `sql/01_sittings_to_score.sql`
2. `sql/02_sitting_responses.sql`
3. `sql/03_final_pupil_stats_score.sql`

I could not log in to BigQuery. I tested the logic on the CSV exports locally, twice, with identical results. It has not been run in BigQuery itself.

## Data assumptions

### Sittings left out

2,509 sittings, 2,342 kept. Removed:

| Left out            | Rows   | Why                                                                          |
|---------------------|--------|------------------------------------------------------------------------------|
| `mock_session`      | 14     | Practice tests.                                                              |
| `entrance_exam`     | 26     | Year groups 6, 11, 14, 15. Not primary-school work (11 are also unfinished). |
| `survey`            | 125    | Wellbeing survey only. It has no right or wrong answers.                     |
| Unfinished          | 2 more | Two year-5 summative tests with no finish time.                              |
| `is_deleted = true` | 0      | None today. The filter is there for the future.                              |

**Year 6:** 452 sittings, 415 kept (27 have no answers yet, so 388 reach the final table). 37 are removed: **1 `entrance_exam`** (`b7eb1a22-3326-46af-86f2-e5d7e508c256`, also unfinished and with no answers, so no answers are lost), 13 `mock_session` and 23 `survey`.

Also:
- **842 answers (56 sessions) have no sitting.** They are dropped, as we cannot tell what test they belonged to.
- **45 finished sittings have no answers**, mostly from September 2026, so they may not have arrived yet. They have no subject or score and are not in the final table.

### How the 2026 score is worked out

GOV.UK has three 2026 tables (English reading out of 50, grammar out of 70, Maths out of 110). Our tests have 8 to 50 questions and no reading/grammar split, so I convert on **percentage**:

1. For each whole percentage, turn it into a raw mark on each table (50% is 25/50, 35/70, 55/110).
2. Look up the scaled score on each and average the three, rounded.
3. The result is one curve used for every subject.

The tables agree closely (50% gives 99 or 100) and only drift apart above 65%.

| Percentage | Score    |
|------------|----------|
| under 5    | no score |
| 5          | 81       |
| 10         | 84       |
| 25         | 92       |
| 40         | 97       |
| 50         | 100      |
| 60         | 103      |
| 70         | 106      |
| 80         | 110      |
| 90         | 115      |
| 98 or more | 120      |

- GOV.UK gives no score under 3 raw marks, which is 2.7% to 6% depending on the table. I used 5%. Below that the score is `NULL`.
- The curve never gives 80 or 117 (the real tables also skip some scores).
- Years 1 to 5, Screeners, Verbal and Non-Verbal Reasoning use the same curve, as there is no table for them. Treat them as a consistent yardstick, not a real SATs result. `year_group_at_sitting` is kept so they can be filtered.
- The percentage is a **running total**: all correct answers so far over all questions so far, for that pupil and subject.

### Missing question rows: the biggest issue

Two different things look like "no answer":

1. **A blank answer:** the row exists with `is_no_attempt = True` (3,220 rows). It is always wrong and the pupil spends about 9 seconds on it, against about 30 on a real answer. It stays in the total.
2. **A missing row:** the sitting says `total_questions = 10` but only 6 rows exist. 1,381 of the 2,297 sittings are like this.

**Were the missing questions never shown? No.** Take sitting `c8a94ab1-9771-4d37-8b83-65d36ab5d8c1` (10 questions, 30 minutes). It has rows for Q1, 2, 3, 6, 9 and 10. About 5.5 minutes pass between Q3 and Q6, and 18 minutes between Q6 and Q9, so the time went on the missing questions. Across all sittings, the time between two consecutive rows that is not explained by the answers is:

| Question numbers missing between the rows | Unexplained time |
|-------------------------------------------|------------------|
| none                                      | about 2 seconds  |
| 1                                         | about 24 seconds |
| 2                                         | about 52 seconds |
| 3                                         | about 79 seconds |

Each missing question adds about 25 seconds, about what a normal answer takes. The gaps are in the middle of tests (only 2 sittings simply stop early). So the questions were shown and took time, but their rows were not recorded.

**The choice:** the percentage is out of `total_questions`. A missing row counts as not correct and stays in the total. The final table has `answer_rows_in_sitting` and `has_missing_rows` so a reader can see when a score rests on missing rows.

**What the other approach (out of the rows present) would change:**

| Latest score per pupil and subject (397) | Out of `total_questions` (used) | Out of rows present |
|------------------------------------------|---------------------------------|---------------------|
| Average score                            | 91.1                            | 95.1                |
| Scores of 100 or more                    | 31                              | 86                  |

324 of the 397 latest scores would change.

Example, Maths, pupil `c9fa06d2-90c4-48b2-88dc-897d1b2668e7`. Test 1 had 10 rows missing:

| Test | Questions | Rows | Correct | Out of `total_questions` (used) | Out of rows present |
|------|-----------|------|---------|---------------------------------|---------------------|
| 1    | 15        | 5    | 0       | 0.0%, no score                  | 0.0%, no score      |
| 2    | 20        | 20   | 12      | 34.3%, score 95                 | 48.0%, score 99     |
| 3    | 15        | 15   | 10      | 44.0%, score 98                 | 55.0%, score 102    |
| 4    | 20        | 20   | 13      | 50.0%, score 100                | 58.3%, score 102    |

Out of rows present, test 1 adds only 5 questions to the total instead of 15, which lifts every later score. That rewards the tests that lost the most rows, so I did not use it.

**Dropping every sitting with missing rows was also rejected.** It removes 60% of sittings, leaves 43 pupil-subjects with nothing, and pushes the average to 101.8.

**Not known:** 1,365 of the 1,381 short sittings have zero correct answers in the rows that exist (sittings with full rows average 56%). If the lost rows were correct answers, those scores are too low. The data cannot say. This is the first thing to ask the owner of the export. 233 of the 397 latest scores come from a sitting with missing rows.

### Other findings

- **Duplicate answers:** the same question in the same sitting appears 2 to 5 times (1,273 extra rows on kept sittings). In 376 questions the copies disagree on `is_correct`. Rule: correct only if every copy says correct. It is cautious and repeatable, and costs credit on about 51 questions (under 0.2%).
- **Screeners** (566 sittings, not in your list), Verbal Reasoning (13) and Non-Verbal Reasoning (3) are also in the data. Science has no answers.
- **575 of 2,297 rows have no score** (running percentage under 5%), 563 of them on sittings with missing rows.
- **Not every pupil has a score.** The brief asks for a score for every pupil in every subject, but only pupils with a kept sitting that has answers can get one. Of the 242 pupils, 164 have a row in the final table. 61 never appear in `assessment_sittings`, and 17 only have sittings that were left out or have no answers. 148 of the 164 have both English and Maths. A complete pupil-by-subject list would need `de_raw.pupils` as a starting point, which I did not use. It is a possible next step.
- **Pupils have many sittings:** 164 pupils, 397 pupil-subject pairs, up to 9 tests for one pair.
- `responses.session_type` is always `MOCK_TEST` and is ignored. `pupil_id` on a response always matches its sitting.

### Reading a score on a given day

The latest row up to a day is the pupil's score on that day:

```sql
SELECT *
FROM adrian_raszkiewicz.final_pupil_stats_score
WHERE finished_at < TIMESTAMP(DATE_ADD(DATE '2026-03-01', INTERVAL 1 DAY))  -- change the date; includes that whole day
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY pupil_id, subject_name
  ORDER BY finished_at DESC, session_id DESC
) = 1;
```

This uses the time the test finished, not when the data loaded. If answers arrive late, an old date can change after the next run.

## Answers

### Step 1: Assign a SATs score

For each pupil and subject I add up their finished tests in order. The percentage is correct answers over all questions so far. A blank or a missing row counts as wrong but stays in the total. That percentage goes through the 2026 KS2 curve above to give an 80-120 score.

### Step 2: A table design that lasts

- **Re-runnable:** each file is one `CREATE OR REPLACE TABLE`, with nothing based on the clock or random order. Ties are broken by `session_id`.
- **Point-in-time:** the final table keeps one row per test, each the score after that test. The query above reads any past day.
- **Ready for the application database:** one flat table, one row per `session_id`, plain types, no nested fields. Partitioned by day and clustered by `pupil_id`.
- **Ready for >100m responses:** `sitting_responses` is partitioned by day and clustered by `pupil_id` and `session_id`. Next step: make files 02 and 03 incremental (only new days and the pupils they touch). I held back because each score depends on all of a pupil's earlier tests, and I wanted something simple to check.
- **Extendable:** topic, subtopic and atom are already on `sitting_responses`, so a colleague can ask topic-level questions.

With more time I would add tests (unique `session_id`, no `NULL` subject, scores within 80-120) and find out why rows are missing.

### Step 3: Predicting GCSE results from primary-school work

Learn from earlier pupils: take those who finished primary school years ago, look at their end-of-primary scores, and see what they went on to get at GCSE. Then, for a pupil today, ask what similar pupils went on to get.

I would need:

- **The outcome:** real GCSE grades, matched to the same pupil. This is the biggest gap, as we have one school year and no GCSE results.
- **The starting point:** real KS2 scaled scores (reading, maths, GPS) plus this platform's scores through years 3 to 6. The trend can matter as much as the level.
- **Context, if lawful and agreed:** school, year group, age in year. Useful, but they can bake in bias.

I would start simple: group pupils by KS2 score band and show the spread of GCSE grades for each band, as a range and not one grade. If that works, a basic regression adds trend and context. The five-year gap means a lot of uncertainty, so I would give a range or probability.

Assumptions: the link between primary and GCSE results stays about the same for new cohorts (test by holding back a whole past cohort); the platform's score is close to a real SATs score (check against real year-6 KS2 results); platform pupils are like the wider population (check it). The missing-rows issue has to be solved first, or the starting scores are too low for most pupils.

