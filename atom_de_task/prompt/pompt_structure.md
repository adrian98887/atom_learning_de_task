# How I structured the prompt

This prompt is the result of my manual investigation of the brief and the sample data provided for the Atom Learning Data Engineer take home exercise.

No SQL queries were provided. The aim here was for the model to write queries from scratch, whilst following architectural decisions and guidelines made by me.

## Structure

1. **The job and the files.** I point the model at the brief and the four CSVs, whilst explaining they are .csv exports, and providing the real raw table names. I also provide the naming structure for the output tables.

2. **What is in the data.** This is the longest part of the prompt. I had already manually checked each one, each finding changes a filter or a join. The are written in rough order of how the raw tables will be used. The model is also told to check each of those findings, not just assume they are correct. If it finds something important that I missed, it checks that too, tells me, and waits until I agree before it uses it.

3. **The architecture.** Bronze is the raw `de_raw` tables, already present. Silver is the intermediate tables, three at most: `sittings` cleans the tests, `sitting_responses` is one row per question on those tests and is where the subject is attached. Gold is `final_pupil_stats_score`. That is where the task in the brief is applied, kept easy to read. Medallion is the name of the architecture.

4. **What each table is.** One line of grain, plus where the rows come from. `sittings` reads `de_raw.assessment_sittings`. `sitting_responses` reads `sittings`, then responses, then course hierarchy. Gold reads `sitting_responses` only.

5. **The score.** I did not write the SATs score formula. I pointed it at the information available in the .pdf brief, as well as two helpful links which I have found myself. The README will contain explanations and examples.

6. **The files and how they should read.** Five files, three of them one `CREATE OR REPLACE TABLE` each. A short header, a comment at the end of a line only when the line is not obvious. The README has three parts: how to run the files, the data assumptions, and a plain answer to each step in the brief. The brief asks for a record of how AI was used. `AI_USAGE.md` is that record: the date, and a few sentences on what this chat actually did. I told the model to keep it short.

7. **What not to add.** No extra tables, no check files, no Python project, no sample outputs. The last line is there because an open brief plus a capable model tends to over-build past the task.

## What I left to the model

I described which rows to keep, how the tables join, and which files to write. Each of these will be checked by the model. I did not write the queries.
The SATs score conversation is for the model to take from referenced given. The README is for the model to write in plain language: how to run the files, the assumptions, a query for the score on a past day, and an answer to each step in the brief.

## Settings

These sit outside the prompt. They are part of how I run it.

**Model.** Claude Sonnet 5.5. Starting from the lowest model family, will only move up if the results suggest so.

**Effort.** High. Reasoning and thinking are important in this exercise.

**Context.** The default setting of 300k.
