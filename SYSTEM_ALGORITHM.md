# System Algorithm and Data Flow

This document walks through the current Flutter/Supabase system from user
input to the output shown or saved. It covers account creation, login, study
content, quizzes, handouts, PDF export, statistics, Learner Points (LP),
leaderboards, and streaks.

The descriptions and formulas follow the code and SQL migrations in this
repository. AI-generated text can vary; the scoring, aggregation, and point
rules are explicit calculations.

## At a glance

```text
Register -> users row
Login -> expiring session token -> secure local storage -> login-day row
Source file -> extracted text -> AI activity -> answer/rating -> attempt row
Quiz attempt -> quiz statistics + quiz LP transactions
Context -> AI handout structure -> preview/style -> locally rendered PDF
Handout PDF -> Import/extract text -> AI quiz (optional, indirect route)
Login/home resume -> one activity date per day -> streak calculation -> daily LP
LP transactions -> all-time balance OR selected-week sum -> leaderboard rank
```

Each arrow is a data transformation or persisted event described below.
Handout generation, quiz generation, and PDF rendering are separate operations.

## 1. Main components

1. **Flutter client (`lib/`)** collects user input, guides learning activities,
   validates responses, and displays results.
2. **Supabase Edge Functions (`supabase/functions/`)** extract text from
   documents and request generated quizzes, flashcards, matching pairs, or
   handouts from AI providers.
3. **Supabase PostgreSQL (`supabase/*.sql`)** validates custom sessions,
   persists activities and attempts, awards learner points, and calculates
   leaderboard and instructor-report data.

The app uses a custom session token stored by `AuthService`; database RPCs and
Edge Functions verify that token before returning or changing user data. This
is a custom session system, not Supabase Auth.

## 2. Register, log in, restore a session, and log out

### Register

**Inputs:** full name, email, password, and role.

The Flutter client trims the full name, trims and lowercases the email, and
sends the values to `register_user`. PostgreSQL then applies these rules:

1. `trim(fullName).length >= 2`.
2. `password.length >= 8`.
3. Public registration role must be exactly `student`.
4. Email must match a basic `name@domain.suffix` pattern and be unique without
   regard to case.
5. Password is stored as a bcrypt hash using `crypt(password, gen_salt('bf',
   12))`; the plain password is not stored.
6. Email is saved lowercase and trimmed, and the account receives a database
   `created_at` timestamp.

**Output:** a user row. Registration itself does not create a session or
automatically sign the user in. Instructor/admin provisioning is separate.

### Log in

**Inputs:** email and password. The client trims/lowercases the email and sends
both to `login_user`.

The database finds the case-insensitive email and checks the submitted
password against the stored bcrypt hash:

```text
validPassword = storedHash == crypt(submittedPassword, storedHash)
```

If valid, it generates 32 random bytes and hex-encodes them (a 64-character
token), inserts a session expiring 30 days after creation, and returns both
the token and user profile.

**Output:** Flutter stores the token in secure storage and uses the returned
profile to build the signed-in experience. Inserting a session also triggers
the login-day recording process described in Section 9.

### Restore and log out

- On app startup, the stored token is sent to `verify_session`. If it is valid
  and unexpired, the user record is returned. If verification fails, the local
  token is deleted and the app treats the user as signed out.
- On logout, the client asks PostgreSQL to delete that session row and deletes
  the token from secure storage even if the RPC fails.
- A token is only accepted when its database session has `expires_at > now()`.

## 3. Source text to quiz, flashcards, or matching

### File input and extraction

The Import screen accepts one PDF, DOCX, or TXT file up to 3 MB. It also asks
for an activity title, activity type, and item count. TXT bytes are decoded on
the Flutter client. PDF/DOCX bytes are base64-encoded and sent to
`extract-source-text`.

The extraction function verifies the session, MIME type, file extension, and
encoded payload size. It extracts:

- **PDF:** selectable text from pages 1 through the final page, in order; at
  most 200 pages.
- **DOCX:** text nodes inside `word/document.xml`, collected recursively and
  joined with spaces.
- **TXT:** handled locally, not by the extraction function.

The extracted text is trimmed and must not be empty or exceed 100,000
characters. A scanned/image-only PDF has no selectable text, so it needs OCR
before import.

### Generation request and output

The Flutter client sends the session token, source file name, extracted text,
requested count, and selected type to an Edge Function. The supported learning
items are:

- multiple-choice, true/false, or mixed quiz questions;
- flashcards containing a question, answer, explanation, and optional hint;
- matching pairs containing left/right text and an explanation.

For quiz generation, the Import UI offers 10, 20, or 30 questions. The service
and Edge Function validate a request count from 1 through 30. The quiz-attempt
table also accepts a historical/configured total of 50, although the current
Import UI does not offer 50. The Edge Function checks the request, builds a
prompt, then tries configured AI-provider/model/key routes. It can launch at
most 10 attempts per request and no more than 2 concurrently; a delayed
request can be hedged with a
second route, and the first valid result wins. Failed or invalid routes can
fall through to another route, subject to the request time budget.

The returned quiz is checked server-side and again in Flutter. Each
multiple-choice question must have a non-empty prompt, exactly four distinct
non-empty options, an integer answer index from 0 to 3, and a non-empty
explanation. True/false questions have two options, `True` and `False`, and a
valid index. The number of questions must equal the requested count.

**Output:** validated activity data presented to the learner. The AI decides
the actual words and educational content; structural validation does not
prove that every generated fact or answer is correct.

### Saving non-quiz learning activities

Generated flashcards and matching pairs are saved as the learner's inventory
item before the study screen opens. The database validates item count and
required strings. Matching prompts and answers must each be unique (case- and
whitespace-normalized).

On completion, the client submits `score` and `totalItems`. The database
verifies that:

```text
1 <= totalItems <= 30
totalItems == number of saved cards or pairs
0 <= score <= totalItems
```

An attempt row is saved. These attempts contribute to inventory best score
and attempt history, but are not quiz attempts and do not trigger the quiz LP
award rules.

For flashcards, a card marked "not known" is put back into the queue near the
front. The activity ends only after all cards are marked known, so a normally
completed non-review session saves `score = totalCards` (100%). That saved
score represents completing the review loop, not first-pass accuracy. A
review round does not save another attempt.

For matching, answer choices are shuffled and shown in batches of at most 10.
The number of batches is `ceil(totalPairs / 10)`. Each pair can be assigned
one answer. When a batch is submitted, each assignment scores 1 if its
original pair index matches the prompt's pair index, otherwise 0:

```text
batchScore = count(correct pair-index assignments in this batch)
totalScore = sum(batchScore for every submitted batch)
matchingPercent = 100 * totalScore / totalPairs
```

The full result is saved after the final batch.

## 4. Quiz questions to quiz result and saved attempt

### Question ordering and option positions

For a newly generated quiz, question order is retained. For a saved quiz
retake, the questions are shuffled. Four-option questions are processed in
order: the algorithm counts how often answer positions 0, 1, 2, and 3 have
been used, randomly chooses among the least-used positions, and avoids the
previous question's position when another equally eligible position exists.
The correct answer stays correct because the correct option is removed from
the old list, distractors are shuffled, then the correct option is inserted
at the chosen position. Two-option true/false answers are not rearranged by
this routine.

### Exact score calculation

The client has an answer slot for each question. Selecting an option records
its zero-based index. Once the learner finishes, the app loops over every
question exactly once:

```text
score = 0
for i = 0 to totalQuestions - 1:
    if selectedAnswer[i] == question[i].answerIndex:
        score = score + 1
```

An unanswered question has a null answer slot, so it does not match the
correct index and contributes zero.

```text
totalQuestions = number of questions
wrongOrUnanswered = totalQuestions - score
scorePercent = 100 * score / totalQuestions
```

The percentage is a calculation; the saved attempt stores the integer
`score` and `total_questions`. A saved quiz can be retaken unlimited times.
When a first attempt is saved, PostgreSQL validates and stores the question
JSON and quiz record. A retake passes the saved quiz ID and no replacement
questions; PostgreSQL checks ownership and that the attempt's question count
matches the saved quiz.

### Worked quiz score example

Suppose 8 answers out of 10 are correct:

```text
score = 8
totalQuestions = 10
wrongOrUnanswered = 10 - 8 = 2
scorePercent = 100 * 8 / 10 = 80%
```

The saved result is `8 / 10`; its score-based LP component is 80 LP.

## 5. Context to study handout

The student dashboard's **Generate study content** action opens a separate
context-based handout flow. This is different from the source-file quiz flow.

### Inputs

The learner provides:

- **Context/topic:** required, trimmed, 1-200 characters.
- **Title color, key-term color, definition color:** selected from the UI
  palette and sent as `#RRGGBB` values.
- **Session token:** required to verify the user.

The UI palette contains deep brown, charcoal, blue, teal, green, purple, red,
and orange. Its initial colors are title `#3B2419`, terms `#2764AE`, and
definitions `#725F53`. The Edge Function fallback colors, used if values are
omitted, are title `#FF7433`, terms `#6A45B5`, and definitions `#6B6B6B`.
Supplied colors must be six-digit hexadecimal `#RRGGBB` strings. Colors affect
presentation, not the educational content.

### Handout generation

The client sends `{sessionToken, context, titleColor, termsColor,
definitionsColor}` to `pdf-generation`. The server normalizes repeated
whitespace in the context, validates the session, and checks its short-lived
topic cache. A cache hit reuses the handout text but applies the current
request's colors.

On a cache miss, the AI is prompted to produce a prose-first learning handout
of approximately 1,200-1,500 words with:

- a title and two-sentence summary;
- 3 sections (4 only when needed), each with 2 subsections in the prompt;
- explanations, optional list items, and either bullet or numbered list style;
- 6-8 key terms and definitions in the prompt.

The server normalizes and validates generated JSON. It truncates content to
configured maximum lengths, accepts 3-4 valid sections, requires at least 4
unique terms, and limits sections to 4, subsections to 3 per section, list
items to 5 per subsection, and terms to 8. Therefore a generated response may
pass server validation with 4 or 5 terms even though the prompt requests 6-8.
The Flutter model validates the response again before making it available for
preview: it requires 3-4 sections, 1-3 subsections per section, 4-8 terms,
and at most 8 key takeaways if that optional field is present. The handout is
held in the current screen state; this flow does not save it as a database
inventory item.

Server-side text limits:

| Field | Maximum characters |
|---|---:|
| Title | 100 |
| Summary | 600 |
| Section heading | 80 |
| Section overview | 600 |
| Subsection heading | 80 |
| Subsection explanation | 1,300 |
| List item | 350 |
| Term | 60 |
| Definition | 350 |

**Output:** structured handout data with title, summary, sections,
subsections, terms, and style colors. AI chooses the prose; its output can
vary and structural validation does not establish factual accuracy.

## 6. Handout to PDF, and handout PDF back to quiz

### Render/export calculation

When the learner taps export, Flutter renders the current structured handout
locally; it does not ask the AI to create a PDF. The exporter:

1. Creates a PDF document using A4 pages and 44-point margins.
2. Loads regular, bold, and symbol fonts.
3. Writes the title, summary, each section, each subsection, and each
   subsection's items in order.
4. Writes the key-terms heading, then each term and definition.
5. If key takeaways are present in the handout object, writes those too.
6. Uses the selected colors for title/section headings, terms, and
   definitions. Text body styles and spacing are fixed by the renderer.
7. Saves PDF bytes, sanitizes the title into a filename, appends `.pdf`, and
   calls the platform's PDF share/download UI.

There is no formula that converts handout text into PDF: the renderer maps
each structured field to a PDF text/widget in sequence. Page count is
automatically determined by content flow.

### Using an exported handout as quiz source

There is **no direct in-memory “handout to quiz” conversion** in the current
app. The documented end-to-end route is:

```text
context -> AI handout object -> local PDF export
         -> select that PDF in Import -> extract selectable text
         -> choose quiz/count -> AI generates quiz questions
```

The exported PDF is a text PDF, so the Import screen can send it through the
same PDF text-extraction path as any other PDF. The resulting extracted text
becomes the quiz-generation source. The quiz generator does not receive the
original handout JSON, its colors, or the AI conversation; it receives only
the extracted text, source name, requested question count/type, and session
token.

## 7. Quiz attempts to student statistics

The source for quiz statistics is the student's saved quiz records and
attempts. For one attempt:

```text
attemptPercent = 100 * score / totalQuestions
```

If `totalQuestions` is zero, a valid saved attempt cannot be created; formulas
guard against division by zero where SQL uses `nullif`.

### Metrics and weighting

Let quiz `q` have attempts `a`. Let:

```text
p(q,a) = 100 * a.score / a.totalQuestions
```

The quiz model also derives several per-quiz summary values:

| Summary value | Input and calculation |
|---|---|
| Question count | Number of question objects saved in that quiz. |
| Attempt count | Number of saved attempt rows included in the quiz object. |
| Latest attempt | Attempt with the greatest `created_at`. |
| First attempt | Attempt with the smallest `created_at`. |
| Best percentage | Maximum of `round(p(q,a))` over attempts. |
| Retention | If at least two attempts qualify, average the two latest percentages for that quiz. |
| Improvement | If at least two attempts qualify, average `p[i] - p[i-1]` across adjacent attempts after chronological ordering. |

The dashboard uses different scopes by metric. It is important not to assume
every metric is limited to the same date range:

| Metric | Dashboard formula and scope |
|---|---|
| **Accuracy** | For attempts in the date window: `100 * sum(score) / sum(totalQuestions)`. Question-weighted, so a 30-question attempt contributes 3 times as much as a 10-question attempt. The standard radar uses the last 28 calendar days, capped by account creation date. |
| **Retention** | For each quiz that has at least 2 attempts in scope, find its 2 most recent attempt percentages, average them; then take the unweighted average of those quiz averages. The standard radar uses all available attempts; the weekly chart applies a 7-day filter. |
| **Improvement** | For each quiz, sort in chronological order and calculate each adjacent difference `p[i] - p[i-1]`; average that quiz's differences. Then take the unweighted average across quizzes with at least 2 attempts. Values are percentage-point changes, not relative percent growth. The standard radar uses all available attempts; the weekly chart applies a 7-day filter. |
| **Consistency** | `100 * numberOfDistinctActiveQuizDays / numberOfEligibleCalendarDays`. A day is active if there is at least one quiz attempt. Eligible days are inclusive from the later of account creation and the window start through today. The standard radar uses 28 days; the weekly chart uses 7 days. |
| **Focus** | For each quiz, select its earliest attempt in scope, then compute `100 * sum(firstAttempt.score) / sum(firstAttempt.totalQuestions)` across those quizzes. Question-weighted. The standard radar uses all available attempts to find each quiz's first attempt; the weekly chart finds first attempts inside the 7-day window. |

Insufficient samples yield no value, not zero. Retention and improvement need
at least two attempts per quiz; accuracy and focus need at least one
eligible question; consistency needs a valid account date and eligible days.

### Worked metric example

Suppose one student has two quizzes:

```text
Quiz A: attempts 6/10 = 60%, then 8/10 = 80%
Quiz B: attempts 9/20 = 45%, then 15/20 = 75%
```

Using all four attempts:

```text
Accuracy = 100 * (6 + 8 + 9 + 15) / (10 + 10 + 20 + 20)
         = 100 * 38 / 60
         = 63.33%

Retention for A = (60% + 80%) / 2 = 70%
Retention for B = (45% + 75%) / 2 = 60%
Overall retention = (70% + 60%) / 2 = 65%

Improvement for A = 80 - 60 = +20 percentage points
Improvement for B = 75 - 45 = +30 percentage points
Overall improvement = (20 + 30) / 2 = +25 percentage points

Focus = 100 * (6 + 9) / (10 + 20) = 50%
```

If the learner attempted quizzes on 5 distinct dates during a 7-day eligible
window:

```text
Consistency = 100 * 5 / 7 = 71.43%
```

The dashboard's student-side statistics are built from quiz attempts.
Flashcard/matching attempts are visible in inventory history but are not
included in these quiz-metric formulas.

### Instructor report metrics

The instructor report RPC calculates related metric categories using SQL
window functions. It partitions attempts by saved quiz, orders them by
timestamp and attempt ID, uses row numbers to identify first and latest
attempts, and uses `lag()` to compare each attempt with the previous attempt.
The current reported values use these scopes:

- **Accuracy:** latest attempt per quiz across all history, question-weighted:
  `100 * sum(score where latestRank = 1) / sum(totalQuestions where latestRank = 1)`.
- **Retention:** average the latest two attempt percentages per quiz when a
  quiz has at least two attempts, then average the quiz values.
- **Improvement:** average consecutive percentage-point changes within each
  quiz, then average the quiz values.
- **Consistency:** distinct quiz-active dates in the last 28 calendar days,
  or since account creation if the account is newer, divided by eligible
  calendar days.
- **Focus:** first-ever attempt per quiz, question-weighted across quizzes.

The report also returns chart samples. For accuracy samples, it returns up to
12 recent attempt percentages from the 28-day range; these samples are not
the same as the all-history, latest-attempt-per-quiz value used for the
reported accuracy metric. Do not assume instructor scopes are identical to
the student-side helper windows.

Other report fields are counts/averages, not extra learning scores:

```text
personalAttemptCount = count of the student's quiz_attempts rows
personalAverageScore = average(100 * score / totalQuestions)
generatedQuizCount = count of the student's saved generated quizzes
```

`personalAverageScore` weights each attempt equally, regardless of quiz
length. Retired classroom activity fields are intentionally returned as
`activity_count = 0`, `completed_activity_count = 0`,
`total_activity_count = 0`, and classroom `average_score = null`; classroom
membership itself remains active.

## 8. Learner Points (LP): event inputs to awards

LP is an append-only ledger of transactions. A database trigger creates
transaction rows after a quiz attempt is inserted or a new activity date is
recorded. The client does not calculate the awards itself. The current
automation awards LP for quiz attempts and newly recorded login/activity days;
handout generation, PDF export, flashcards, and matching sessions do not have
LP-award triggers.

### Quiz attempt grouping

Attempts for the same learner are grouped by:

```text
if quiz_id exists:
    quizGroup = "quiz:" + quiz_id
else:
    quizGroup = "legacy:" + md5(
        lowercase(trim(title)) + separator + lowercase(trim(source_file)
    )
```

Within one user and quiz group, attempts are numbered chronologically by
`(created_at, id)`. A per-user database advisory lock serializes simultaneous
quiz inserts while this attempt number and its awards are computed.

### Exact quiz LP formulas

For each inserted attempt, PostgreSQL creates these independent awards:

```text
scoreLP = round(100 * score / totalQuestions)

if attemptNumber == 1: attemptLP = 50
if attemptNumber == 2: attemptLP = 25
if attemptNumber >= 3: attemptLP = 0

if score == totalQuestions and this quiz has not received perfect LP:
    perfectLP = 150
else:
    perfectLP = 0

attemptTotalLP = scoreLP + attemptLP + perfectLP
```

The first-perfect condition is enforced by a unique transaction key per user
and quiz group. The score award is made for **every** attempt. The attempt
bonus is only for attempt 1 and 2. Later attempts do not lose points.

| Attempt/result | Score LP | Attempt bonus | Perfect bonus | Total for that attempt |
|---|---:|---:|---:|---:|
| First attempt, 8/10 | 80 | 50 | 0 | 130 |
| Second attempt, 10/10, first perfect | 100 | 25 | 150 | 275 |
| Third attempt, 6/10 | 60 | 0 | 0 | 60 |
| Later perfect attempt after perfect LP already granted, 10/10 | 100 | 0 | 0 | 100 |

For the first attempt row, `round(100 * 8 / 10) = 80`. If a perfect result
occurs on attempt 1, it can earn `100 + 50 + 150 = 300 LP`.

### Idempotency and total balance

Each event has a stable `source_key`; a unique constraint on `(user_id,
source_key)` makes re-running the same event insertion a no-op instead of
double-awarding it.

```text
allTimeLP(user) = sum(points_delta for every ledger row belonging to user)
```

The score percentage is rounded to an integer before being stored. The ledger
constraints require fixed bonuses to remain exactly 50, 25, and 150, and
require every `points_delta >= 0`; points are accumulated, not deducted.

For an existing deployment, `learner_points_backfill.sql` can import historic
quiz attempts and login days into the ledger. It uses the same grouping and
award rules, ranks attempts by timestamp/ID, awards only the first perfect
attempt in each quiz group, derives consecutive-day streak groups, and uses
the same unique source keys. Re-running it is safe because conflicts on
`(user_id, source_key)` are ignored. Without the backfill migration, the live
triggers award events inserted after the automation was installed; they do
not automatically create ledger rows for every older event.

## 9. Login/activity date to streak and daily LP

### Recording a date

When `login_user` creates a new `user_sessions` row, a database trigger inserts
the current database calendar date into `user_login_days`. The primary key is
`(user_id, login_date)`, so only one date row can exist for the learner per
day.

When the student home screen resumes, it calls `record_user_activity_day`
with the session token. That RPC verifies the token and attempts to insert
today's date too. If the login already recorded the same date, the unique key
prevents a second insertion. The points trigger only runs for a newly inserted
date.

### Consecutive date calculation

For a newly inserted date `D`, the recursive SQL starts with a streak length
of 1 at `D`, then follows rows for `D-1`, `D-2`, and so on while dates are
consecutive:

```text
streakLength(D) =
    1 + number of consecutive user_login_days immediately before D

effectiveStreak = min(streakLength(D), 7)
dailyLP = 100 * effectiveStreak
```

This means the reward per newly recorded date is:

| Consecutive day number | Daily LP |
|---:|---:|
| 1 | 100 |
| 2 | 200 |
| 3 | 300 |
| 4 | 400 |
| 5 | 500 |
| 6 | 600 |
| 7 or later | 700 |

The value is not a one-time milestone bonus: the SQL awards the indicated
amount on each newly recorded day, capped at 700 LP per day. A skipped day
breaks the chain; the next recorded date starts a new streak of 1. The unique
source key `daily_login_streak:YYYY-MM-DD` prevents the same user/date reward
from being inserted twice.

`get_login_activity` returns the ordered saved dates for the profile calendar.
It returns dates, not a separately stored current streak counter; consecutive
days can be counted from those dates for display.

## 10. Weekly leaderboard and what “reset” means

The leaderboard does **not** clear or reset the LP ledger. Every point
transaction remains available for the all-time balance. The weekly leaderboard
calculates a temporary total by filtering ledger rows to one calendar-week
interval:

```text
weekStart = date_trunc('week', now()) + weekOffset * 1 week
weekEnd   = weekStart + 1 week

weeklyLP(student) =
    sum(points_delta where created_at >= weekStart
                       and created_at < weekEnd)
```

The SQL calendar week begins Monday (`date_trunc('week', ...)` in
PostgreSQL). The interval is start-inclusive and end-exclusive, so a
transaction at the exact next week's start belongs only to the next week.
Database timestamp/time-zone configuration determines how `now()` and the
timestamp boundaries are interpreted.

Available offsets:

| Offset | Range selected |
|---:|---|
| `0` | This calendar week |
| `-1` | Previous calendar week |
| `-2` | Two calendar weeks ago |

At the next Monday boundary, the `0` query begins summing the new week from
zero, but old transactions are not deleted; the old total is still part of
all-time LP and can be viewed using the previous-week selector.

All student users are included, even with no points (their weekly sum is
zero). The database sorts by weekly LP descending, then full name ascending,
then user ID ascending. `row_number()` assigns distinct sequential positions,
so equal LP totals are broken by name and ID rather than sharing a rank. The
list returns at most 99 students. The profile's weekly-rank RPC uses the same
current-week calculation.

## 11. API endpoint reference

This section lists the endpoints the Flutter app currently calls. The actual
Supabase project URL is configured at build/run time, so these URLs use
`<SUPABASE_URL>` as a placeholder. The Supabase Flutter SDK adds the project
API key and JSON/authorization transport headers. The custom `sessionToken`
below is an app session value in the request body; it is not a Supabase Auth
JWT.

### Endpoint forms and common behavior

| Kind | HTTP endpoint form | Request |
|---|---|---|
| PostgreSQL RPC | `POST <SUPABASE_URL>/rest/v1/rpc/<function_name>` | JSON object whose keys are the SQL function's `p_...` parameter names. |
| Edge Function | `POST <SUPABASE_URL>/functions/v1/<function_name>` | JSON body shown in the function table below. |
| Realtime notification broadcast | Supabase Realtime channel broadcast | The client listens to `student_notifications_changed`; the notification list itself is reloaded by RPC. |

Unless stated otherwise, RPCs use `p_session_token` to identify the user and
return a PostgREST error if the token is missing, invalid, or expired.
Role-specific RPCs also reject a valid token with the wrong role. On success,
`RETURNS void` means an empty/null RPC result; SQL exceptions are surfaced as
PostgREST errors. Edge Functions generally return JSON `{ "error": "..." }` for failures.
Generation providers may also add `retryable`, `attempts`, and `Retry-After`;
these fields depend on the failure path.

### Authentication and account endpoints

| RPC / function | Request body or RPC parameters | Successful response | Notes |
|---|---|---|---|
| `registration-otp` Edge Function, `action: "send"` | `{ "action": "send", "email": string }` | The client requires `{ "success": true }`; it optionally displays the string `message`. | Called before account creation. The Edge Function implementation is **not present** under this repository's `supabase/functions`; its server-side validation, expiry, retry policy, and exact error schema cannot be verified here. |
| `registration-otp` Edge Function, `action: "verify"` | `{ "action": "verify", "email": string, "otp": string, "password": string }` | The client requires `{ "success": true }`; then it calls `register_user`. | This function is not present in the repository. Email is trimmed in the registration screen; the password is passed unchanged. |
| `register_user` RPC | `p_full_name: string`, `p_email: string`, `p_password: string`, `p_role: string` | `void` | Name is trimmed, email trimmed/lowercased. Current public registration only accepts student role; name length >= 2, password length >= 8, valid email syntax, and unique email are required. |
| `login_user` RPC | `p_email: string`, `p_password: string` | `{ "session_token": string, "user": { "id": number, "full_name": string, "email": string, "role": string, "created_at": timestamp } }` | Creates a 30-day session. Invalid credentials produce a database error. Client stores the token securely. |
| `verify_session` RPC | `p_session_token: string` | `{ "id": number, "full_name": string, "email": string, "role": string, "created_at": timestamp }` | Used to restore a stored session and by Edge Functions for token verification. |
| `logout_user` RPC | `p_session_token: string` | `void` | Deletes the corresponding session row. Client removes local secure storage in a `finally` block. |

### Learning activity and quiz endpoints

| RPC / function | Request body or RPC parameters | Successful response | Notes |
|---|---|---|---|
| `extract-source-text` Edge Function | `{ "sessionToken": string, "fileName": string, "fileBase64": string, "mimeType": string }` | `{ "text": string }` | PDF or DOCX only; valid extension/MIME pair; base64 payload <= 4,500,000 characters; PDF <= 200 pages; extracted text <= 100,000 characters. Errors include invalid body/file/session, unsupported type, no selectable text, too many pages, or extraction failure. |
| `generate-quiz` Edge Function | `{ "sessionToken": string, "questionCount": integer, "sourceFileName": string, "sourceText": string }` | `{ "questions": Question[] }` | Four-option multiple-choice generation. Count 1-30, source text 1-100,000 characters, filename 1-200 characters. Each question has `question`, `options`, `answerIndex`, and `explanation`. |
| `generate-true-or-false` Edge Function | Same fields as `generate-quiz` | `{ "questions": Question[] }` | Questions use two options, `True` and `False`, with an answer index of 0 or 1. |
| `generate-mixed-quiz` Edge Function | Same fields as `generate-quiz` | `{ "questions": Question[] }` | Server sets true/false count to `max(1, min(questionCount - 1, round(questionCount * 0.3)))`; multiple-choice count is the remaining total. |
| `generate-flashcards` Edge Function | `{ "sessionToken": string, "questionCount": integer, "sourceFileName": string, "sourceText": string }` | `{ "cards": Flashcard[] }` | Count 1-30. A card contains non-empty `question`, `answer`, `explanation`, and optional string `hint`. |
| `generate-matching` Edge Function | Same fields as `generate-flashcards` | `{ "pairs": MatchingPair[] }` | Count 1-30. A pair contains non-empty `left`, `right`, and `explanation`; the saved-inventory RPC also enforces unique normalized left and right labels. |
| `save_quiz_attempt` RPC | `p_session_token`, `p_title`, `p_score`, `p_total_questions`, `p_source_file`, `p_quiz_id` (nullable UUID), `p_questions` (JSON array for new quiz; null for retake) | UUID of the saved quiz | Validates score range and total count (10, 20, 30, or 50), ownership of an existing quiz for retakes, and generated question structure. Inserts the attempt and triggers LP awards. |
| `list_saved_quizzes` RPC | `p_session_token` | Array of rows: `id`, `title`, `source_file`, `questions`, `created_at`, `attempts[]`, `classroom_activity_id`, `classroom_name`, `max_attempts` | Current `quiz_attempts.sql` returns saved quizzes with each attempt's `score`, `total_questions`, and `created_at`; legacy classroom fields are null. |
| `list_recent_quiz_attempts` RPC | `p_session_token` | Rows with `id`, `title`, `score`, `total_questions`, `source_file`, `created_at` | SQL compatibility RPC. The current Flutter quiz service loads saved quiz summaries through `list_saved_quizzes`. |
| `save_quiz_draft` RPC | `p_session_token`, `p_title`, `p_source_file`, `p_questions` | UUID | The Flutter instructor flow calls this endpoint. In this repository its SQL definition exists only in the retired `classroom_activities.sql` migration, which README says not to apply on a new deployment. It may be unavailable on a clean current schema unless separately migrated; treat that as a deployment dependency. |
| `get_quiz_attempt_learner_points` RPC | `p_session_token`, `p_quiz_id` (UUID) | Integer LP earned for the latest saved attempt | Looks up the user's latest attempt for that saved quiz and sums linked score/first-or-second/perfect reward transactions. Missing quiz attempt or missing LP migration returns an RPC error. |
| `save_learning_inventory_item` RPC | `p_session_token`, `p_item_type` (`flashcards` or `matching`), `p_title`, `p_source_file`, `p_content` (JSON array) | UUID of the new inventory item | Requires 1-30 items and valid fields. Matching left/right values must each be unique after trim/lowercase normalization. |
| `save_learning_inventory_attempt` RPC | `p_session_token`, `p_item_id`, `p_score`, `p_total_items` | `void` | Requires item ownership, total equal to stored content length, and `0 <= score <= total`. |
| `list_learning_inventory_items` RPC | `p_session_token` | Array of `{ id, item_type, title, source_file, content, created_at, attempts[] }` | Each attempt contains `score`, `total_items`, and `created_at`; ordered by item recency, attempts newest first. |
| `set_learning_inventory_favorite` RPC | `p_session_token`, `p_item_type` (`quiz`, `flashcards`, or `matching`), `p_item_id`, `p_is_favorite: boolean` | `void` | Checks the user owns the item; true inserts idempotently, false removes the favorite. |
| `list_learning_inventory_favorites` RPC | `p_session_token` | Rows `{ item_type, item_id }` | Newest favorites first. Flutter maps them to `type:id` keys. |

### Learner profile, LP, and leaderboard endpoints

| RPC | Request parameters | Successful response | Notes |
|---|---|---|---|
| `get_learner_points` | `p_session_token` | Integer all-time LP | Sum of all `points_delta` values for the verified user; empty ledger returns 0. |
| `get_login_activity` | `p_session_token` | `{ "login_dates": ["YYYY-MM-DD", ...] }` | Dates ordered ascending; client parses them into calendar dates. |
| `record_user_activity_day` | `p_session_token` | `void` | Called when the student home resumes. Inserts today's date if not already present; a new date can trigger streak LP. |
| `get_weekly_learner_points` | `p_session_token`, `p_week_offset` (`0`, `-1`, or `-2`) | Rows `{ rank, user_id, full_name, weekly_points }` | Up to 99 student rows for the selected Monday-to-Monday week. |
| `get_my_weekly_learner_rank` | `p_session_token` | Integer rank, or null if no result | Uses the current calendar week's weekly LP sums and tie-breaking rules. |

### Classroom endpoints

| RPC | Request parameters | Successful response | Role/access |
|---|---|---|---|
| `create_instructor_classroom` | `p_session_token`, `p_name`, `p_subject`, `p_icon_key` | Object `{ id, name, subject, code, icon_key, created_at, student_count, activity_count }` | Instructor only. Name and subject required; icon key must be one of `book`, `science`, `computer`, `calculate`, `palette`, `language`, `history`, `music`. Server generates a unique share code. |
| `list_instructor_classrooms` | `p_session_token` | Array of classroom objects with ID, name, subject, code, icon, creation time, student count, activity count | Instructor only; own classrooms, newest first. |
| `get_instructor_dashboard_stats` | `p_session_token` | `{ student_count, active_class_count, quizzes_created_count, classroom_performance[] }` | Instructor only. Counts unique students across owned classrooms. Retired activity metrics are zero/null. |
| `delete_instructor_classroom` | `p_session_token`, `p_classroom_id` | `void` | Instructor can delete only an owned classroom; unknown/not-owned ID errors. |
| `join_classroom` | `p_session_token`, `p_code` | Classroom object `{ id, name, subject, code, icon_key, created_at, student_count, activity_count }` | Student only. Code is trimmed/uppercased by client; repeated membership insert is idempotent. |
| `list_student_classrooms` | `p_session_token` | Array of classroom objects | Student only; joined classrooms newest membership first. |
| `list_instructor_classroom_students` | `p_session_token`, `p_classroom_id` | Array `{ id, full_name, email, joined_at }` | Instructor must own the classroom. |
| `list_student_classroom_classmates` | `p_session_token`, `p_classroom_id` | Array `{ id, full_name, email: "", joined_at }` | Student must be a member. The SQL intentionally returns empty email for classmates. |
| `remove_instructor_classroom_student` | `p_session_token`, `p_classroom_id`, `p_student_id` | `void` | Instructor must own classroom and student membership; historical quiz attempts are retained. |

### Reports, materials, notifications, and admin endpoints

| RPC | Request parameters | Successful response | Notes |
|---|---|---|---|
| `get_instructor_reports` | `p_session_token` | Array of classroom objects, each with classroom metadata and `students[]` | Instructor only. Student entries include identity/enrollment dates, attempt counts/averages, saved quiz count, 5 progress percentages, and metric samples. Retired activity fields are zero/null. |
| `list_instructor_learning_materials` | `p_session_token` | Array `{ id, title, source_file, created_at, question_count, folder_id, folder_name }` | Instructor sees their saved generated quizzes. |
| `list_instructor_learning_material_folders` | `p_session_token` | Array `{ id, name, created_at }` | Instructor's folders, alphabetically ordered. |
| `create_instructor_learning_material_folder` | `p_session_token`, `p_name` | `{ id, name, created_at }` | Name length 1-80; names unique case-insensitively per instructor. |
| `assign_instructor_learning_material_folder` | `p_session_token`, `p_quiz_id`, `p_folder_id` (nullable UUID) | `void` | Assigns or moves an owned quiz; null folder removes its current assignment. |
| `delete_instructor_learning_material` | `p_session_token`, `p_quiz_id` | `void` | Deletes an owned saved quiz; attempt-record retention follows database FK behavior. |
| `list_student_notifications` | `p_session_token` | Up to 100 rows `{ id, type, title, message, created_at, classroom_id, is_read }` | Student only, 90-day window. Types include daily points, quiz points, ended streak, weekly rank, classroom joined/removed. |
| `mark_student_notifications_read` | `p_session_token`, `p_notification_ids: string[]` | `void` | Inserts read markers idempotently. Empty list is short-circuited by client. |
| `list_instructor_notifications` | `p_session_token` | Rows `{ id, type, title, message, created_at, is_read, classroom_id }` | Instructor only; new classroom memberships from the last 90 days. |
| `mark_instructor_notifications_read` | `p_session_token`, `p_notification_ids: string[]` | `void` | Inserts read markers idempotently. |
| `get_admin_overview` | `p_session_token` | `{ student_count, instructor_count, classroom_count, recent_updates[] }` | Admin only. Recent update objects are `{ type, title, description, created_at }`, limited to 8. |

### AI and document Edge Functions

All generation functions use HTTP `POST` with JSON. Quiz/activity generation
requests use `sessionToken`, `questionCount`, `sourceFileName`, and
`sourceText`; the shared success/error behavior and field constraints are
specified above. The Edge Function validates the session, calls AI providers
server-side, and returns generated JSON; provider API keys are never sent by
Flutter.

| Function endpoint | Additional input | Success JSON | Main errors |
|---|---|---|---|
| `/functions/v1/extract-source-text` | `fileName`, `fileBase64`, `mimeType` | `{ "text": string }` | HTTP 400 invalid JSON/file/type/text, 401 invalid session, 500 missing Supabase configuration, 503 verification failure, extraction failure. |
| `/functions/v1/generate-quiz` | None beyond shared generation fields | `{ "questions": Question[] }` | HTTP 400 invalid request, 401 invalid/expired session, 500 missing AI/Supabase configuration, 503 if providers are cooling down/rate-limited, 504 for timeouts, 502 for provider/auth/model/invalid-output failures; canceled requests may return 499. |
| `/functions/v1/generate-true-or-false` | Same | `{ "questions": Question[] }` | Same generation error classes; output must use two-option true/false items. |
| `/functions/v1/generate-mixed-quiz` | Same | `{ "questions": Question[] }` | Same generation error classes; mixed counts use the formula above. |
| `/functions/v1/generate-flashcards` | Same | `{ "cards": Flashcard[] }` | Same generation error classes; exact requested count is required. |
| `/functions/v1/generate-matching` | Same | `{ "pairs": MatchingPair[] }` | Same generation error classes; exact requested count is required. |
| `/functions/v1/pdf-generation` | `context` (1-200 chars); optional `titleColor`, `termsColor`, `definitionsColor` hex colors | `{ "handout": { title, summary, sections[], terms[] }, "style": { titleColor, termsColor, definitionsColor } }` | HTTP 400 invalid body/context/colors, 401 invalid/expired session, 500 configuration/key errors, provider/session errors depend on the handler. This returns structured content, not PDF bytes. |
| `/functions/v1/registration-otp` | `action` is `send` or `verify`; see auth table for other fields | Client requires `{ "success": true }`; send can include `message` | Function source is not in this repo, so server behavior/status/schema beyond the client contract is unknown. |

For generated question objects, fields are:

```json
{
  "question": "string",
  "options": ["option text"],
  "answerIndex": 0,
  "explanation": "string"
}
```

For generated activity objects:

```json
{
  "cards": [
    { "question": "string", "answer": "string", "explanation": "string", "hint": "optional string" }
  ],
  "pairs": [
    { "left": "string", "right": "string", "explanation": "string" }
  ]
}
```

The examples show the shape of the corresponding response property; a request
to one endpoint returns only its property (`questions`, `cards`, or `pairs`).

### RPCs not directly called by the current Flutter client

Some SQL functions support triggers, migrations, or older features rather than
current direct client calls:

- `record_user_login_day`, `award_quiz_learner_points`,
  `award_login_day_learner_points`, and lock functions are database triggers,
  not HTTP endpoints.
- `list_recent_quiz_attempts` is an exposed SQL compatibility RPC but the
  current app reads `list_saved_quizzes`.
- `post_classroom_activity`, `list_classroom_activities`,
  `delete_classroom_activity`, and
  `submit_classroom_activity_attempt` are retired classroom-activity APIs.
  Their historical migration files are not part of new deployment setup.
- `save_quiz_draft` is still invoked by the instructor client but its SQL
  definition is only in the retired `classroom_activities.sql`; verify that
  it exists in the target database before relying on that flow.

### Client call-site map

| App feature | Client implementation |
|---|---|
| Register/login/profile/LP/streak/rank | [`lib/services/auth_service.dart`](./lib/services/auth_service.dart) |
| Registration OTP | [`lib/screens/auth/register_screen.dart`](./lib/screens/auth/register_screen.dart) |
| Quiz generation and persistence | [`lib/services/quiz_service.dart`](./lib/services/quiz_service.dart) |
| Flashcard/matching generation and inventory RPCs | [`lib/services/learning_mode_service.dart`](./lib/services/learning_mode_service.dart) |
| Classroom and roster RPCs | [`lib/services/classroom_service.dart`](./lib/services/classroom_service.dart) |
| Instructor reports/materials/notifications | [`lib/services/instructor_reports_service.dart`](./lib/services/instructor_reports_service.dart), [`lib/services/instructor_learning_materials_service.dart`](./lib/services/instructor_learning_materials_service.dart), [`lib/services/instructor_notification_service.dart`](./lib/services/instructor_notification_service.dart) |
| Student notifications and Realtime refresh | [`lib/services/student_notification_service.dart`](./lib/services/student_notification_service.dart) |
| Admin overview | [`lib/services/admin_overview_service.dart`](./lib/services/admin_overview_service.dart) |
| Weekly leaderboard | [`lib/services/leaderboard_service.dart`](./lib/services/leaderboard_service.dart) |
| Handout generation | [`lib/services/handout_service.dart`](./lib/services/handout_service.dart) |

There are no direct `.from(table)` reads in the current Flutter client; data
operations are through the listed RPCs, Edge Functions, and notification
Realtime broadcast.

## 12. Important loops and their data

| Loop / iteration | Input data | Purpose |
|---|---|---|
| Login/session verification | Submitted email/password or stored token | Find a user, validate a stored hash/session expiry, and return a user profile/token. |
| PDF page loop | Pages `1..numPages` | Extract page text in source order. |
| DOCX traversal | Parsed XML/JSON-like document tree | Collect text nodes recursively. |
| AI route attempts | Active model/key candidates, bounded per request | Retry transient failures and return a valid generation. At most 10 attempts are launched per quiz request, with no more than 2 concurrently. |
| Handout normalization | Generated sections, subsections, items, and terms | Drop malformed entries, truncate overlong text, enforce section/term bounds, and deduplicate terms. |
| PDF rendering | Structured handout lists | Write section, subsection, list-item, and term widgets in order into a paginated A4 PDF. |
| Question scoring | All submitted questions | Count exact answer-index matches. |
| Inventory activity | Cards or matching pairs | Track self-ratings or matching assignments and accumulate the activity score. |
| Metric aggregation | Quizzes, then their attempts or active dates | Compute accuracy, retention, improvement, consistency, and focus. |
| Streak calculation | Consecutive stored user dates | Count consecutive dates backward from the newly recorded date. |
| Leaderboard aggregation | Student users and point transactions in the selected week | Sum weekly LP and rank students with stable tie-breakers. |
| LP backfill (when explicitly run) | Historical quiz attempts and login dates | Rank past events, derive the corresponding LP transactions, and ignore duplicate source keys. |

These are linear scans over the relevant rows/items, apart from database grouping
and ordering used for aggregation and ranking. AI generation time depends on
the external provider and configured retries; it is not part of the scoring
calculation.

## 13. Implementation references

- Flutter quiz rules and progress helpers: [`lib/services/quiz_service.dart`](./lib/services/quiz_service.dart)
- Quiz presentation and score submission: [`lib/screens/quiz_screen.dart`](./lib/screens/quiz_screen.dart)
- File selection and source-to-activity flow: [`lib/screens/import_screen.dart`](./lib/screens/import_screen.dart)
- Flashcard/matching scoring: [`lib/screens/study_activity_screens.dart`](./lib/screens/study_activity_screens.dart)
- Learning inventory models and RPC client: [`lib/services/learning_mode_service.dart`](./lib/services/learning_mode_service.dart)
- Registration, login, and session operations: [`lib/services/auth_service.dart`](./lib/services/auth_service.dart), [`supabase/custom_auth.sql`](./supabase/custom_auth.sql)
- Handout input, response validation, and generation RPC: [`lib/screens/context_content_screen.dart`](./lib/screens/context_content_screen.dart), [`lib/services/handout_service.dart`](./lib/services/handout_service.dart), [`supabase/functions/pdf-generation/index.ts`](./supabase/functions/pdf-generation/index.ts)
- Local PDF rendering and export: [`lib/services/handout_pdf_exporter.dart`](./lib/services/handout_pdf_exporter.dart)
- Quiz persistence and validation: [`supabase/quiz_attempts.sql`](./supabase/quiz_attempts.sql)
- LP ledger and triggers: [`supabase/learner_points.sql`](./supabase/learner_points.sql), [`supabase/learner_points_automation.sql`](./supabase/learner_points_automation.sql)
- Historical LP import: [`supabase/learner_points_backfill.sql`](./supabase/learner_points_backfill.sql)
- Streak dates and activity recording: [`supabase/learning_streak.sql`](./supabase/learning_streak.sql)
- Weekly rankings: [`supabase/learner_points_leaderboard.sql`](./supabase/learner_points_leaderboard.sql)
- Instructor metrics: [`supabase/instructor_reports.sql`](./supabase/instructor_reports.sql)
- Text extraction and quiz generation: [`supabase/functions/extract-source-text/index.ts`](./supabase/functions/extract-source-text/index.ts), [`supabase/functions/generate-quiz/index.ts`](./supabase/functions/generate-quiz/index.ts)
