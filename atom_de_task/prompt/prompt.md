You are doing a data-engineer take-home. The brief is take-home-task-data-engineer.pdf. The data is inside the four CSV files in this folder, although these are manual CSV exports. In BigQuery the table names are:
- de_raw.assessment_sittings
- de_raw.responses 
- de_raw.pupils
- de_raw.course_hierarchy

I have found some information about this data, use the below findings to steer your answer. DO NOT assume these findings are correct, check them before producing anything.
If you find something important that I missed, check it, tell me what you found, and wait. Use it in the tables only after I agree.

What is in the data:

de_raw.assessment_sittings:
- session_id is unique. A sitting is one pupil and one subject.
- is_deleted is a Boolean value, every row reads False. However, still filter out records that are True, if these appear in the future.
- 13 rows are is_complete = false. Filter these out. The finished_at is also null for these rows.
- Exclude session_type = 'mock_session'. Also exclude 'entrance_exam' rows, these are for year groups of 11,14,15. There is one row for year 6 but it's not complete. So only keep session_type = 'summative_assessment'.
- style only has 'fixed_question' and 'survey' left. Only 125 of these rows are 'survey'. When joined with responses and course_hierarchy, these rows have a subject = 'Wellbeing'. This should not be used to calculate SATs scored, check this logic. And if correct, only keep style = 'fixed_question'.

de_raw.responses:
- session_type is MOCK_TEST for all rows, can be ignored.
- session_id is repeated, once per question, with different question_id per session_id.
- responses can be joined to assessment_sittings on session_id only, the pupil_id column matches when done like so.
- Some responses have no assessment_sittings. Drop them. This means answers cannot be tied to a test sitting. Double check this logic.
- is_no_attempt = True, means the question wasn't attempted, leave those rows in, as that is a wrong answer.

de_raw.course_hierarchy:
- Each question_id belongs to a subject_id.  
- When joined with responses, Science has no answers

de_raw.pupils:
- Disregard this table, it's not needed, it gives us no new information. All the rows are is_deleted = False.

Build a medallion layout, and nothing more.
- Bronze is the raw data. So the de_raw tables already present.
- Silver is two or max three intermediate tables.
    - adrian_raszkiewicz.sittings
        - Clean the data here. Filter out sittings we do not care about.
        - source is de_raw.assessment_sittings
    - adrian_raszkiewicz.sitting_responses
        - One row per question on the sittings we kept. Attach the subject and question information.
        - source is adrian_raszkiewicz.sittings, join responses to get question/answer information, join course_hierarchy to get subject information.
- Gold is the final table. Named: adrian_raszkiewicz.final_pupil_stats_score
    - Apply business logic here, according to 'The Task' section in take-home-task-data-engineer.pdf
    - source is adrian_raszkiewicz.sitting_responses
    - Try to make the final model as simple, easily readable as possible. Do not have more than 3 CTE's.


sittings: One row per finished summative fixed-question test. These are the tests that will be valid going forward.

sitting_responses: One row per question. Along with subject and question/answer information.

Map the percentage onto 80-120 scaled SATs score from the 2026 KS2 tables on GOV.UK referenced in the .pdf attached. 
More info on the raw score compared to scaled score can be found here: 
    - https://www.gov.uk/government/publications/key-stage-2-tests-2026-scaled-scores/2026-key-stage-2-scaled-score-conversion-tables
    - https://calks.uk/calculator/ks2-sats-scaled-score-calculator/ 


Write exactly these files:
sql/01_sittings_to_score.sql
sql/02_sitting_responses.sql
sql/03_final_pupil_stats_score.sql
README.md
AI_USAGE.md

Each SQL file is one CREATE OR REPLACE TABLE. Running it again replaces the table with the same rows. A short header at the top of each file, in plain and simple words. 
Comments at the end of a line when the line is not obvious.

README:
How to run it
- The bronze, silver, and gold tables, in a few sentences.
- The three SQL files, in order.

Data assumptions
- Which sittings are left out, and why, in plain language.
- The 2026 scaled score conversion logic used.
- Any other important data quality findings.
- The query that reads final_pupil_stats_score as it stood on a given day.

Answers
- Answer each of the Steps under The Task in the .pdf
- Do this in plain, human readable, very simple to follow language.


AI_USAGE.md: a short note of this chat. Include today's date. Say that the four tables and the 2026 KS2 tables were checked, and that the three SQL files were written from that, according to what is needed to answer the tasks in the .pdf brief.


Do not add more tables, check files, a Python project, or sample outputs. When you finish, the only new files are the five listed above.
