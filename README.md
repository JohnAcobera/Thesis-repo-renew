# thesis_repo_renew

## Supabase configuration

Copy `.env.example` to `.env` and set `SUPABASE_URL` and
`SUPABASE_ANON_KEY` to your Supabase project URL and public anon/publishable
key. The `.env` file is ignored by Git and is not bundled as an app asset.

Pass the file to Flutter when running or building so the values are compiled
into the app. In VS Code, start the `Flutter (custom Supabase auth)` launch
configuration with F5. From a terminal, use:

```sh
flutter run --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env --no-wasm-dry-run
```

For CI, pass values from the build environment with
`--dart-define=SUPABASE_URL="$SUPABASE_URL"` and
`--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"`, or provide a securely
managed `.env` file. The Supabase anon/publishable key is public in a web app;
never use a service-role key. Protect data with Supabase Row Level Security.
The web build command above targets the standard JavaScript output. Building
with `--wasm` also requires replacing `flutter_secure_storage` with a
WebAssembly-compatible storage implementation.

For hosting under a subpath, set the corresponding base href, for example:

```sh
flutter build web --dart-define-from-file=.env --no-wasm-dry-run --base-href=/your-subpath/
```

If the profile shows "Joined: Not available", re-run
`supabase/custom_auth.sql` in the Supabase SQL Editor. Its login and
restored-session RPCs return `users.created_at`, which the profile displays as
the account's join date. Re-run this migration to restrict public
self-registration to student accounts; instructor accounts must be created
through the admin workflow once it is available. The migration allows the
`admin` role for accounts created directly in the database. Set
`password_hash` to `crypt('your-strong-password', gen_salt('bf', 12))` when
creating an admin; do not store the password as plain text.

## Admin panel

The admin login is available directly at `/admin` in a Flutter web build, or
at `/#/admin` when using Flutter's default hash-based web URL. It is not linked
from the main app. Re-run `supabase/custom_auth.sql` before creating an admin
account with the `admin` role. Public self-registration remains student-only.
Run the web app locally with
`flutter run -d chrome --dart-define-from-file=.env`. When deploying with
path-based URLs, configure the web host to serve `index.html` for `/admin`.
Run `supabase/admin_overview.sql` after `custom_auth.sql`, `classrooms.sql`,
`quiz_attempts.sql`, and `classroom_activities.sql` to enable the admin
overview. It reports student, instructor, and classroom totals plus the eight
most recent account, classroom, enrollment, and posted-activity updates.

## Generative quizzes

Run `supabase/quiz_attempts.sql` (or re-run it on an existing project) in the
Supabase SQL Editor to enable saved quizzes and the custom-session RPCs. Re-run
it to update the save function to accept both multiple-choice and True or False
questions.
Student-generated quizzes are saved after a student completes them. Instructors
can save generated quizzes or post them to selected classrooms with a start
time and deadline. Students can take posted activities from their classroom
while they are available, and can retake them until the instructor-set attempt
limit is reached. The student dashboard shows recent quiz scores and classroom
attribution; saved student quizzes can be retaken from the dashboard. The
recent activity list includes completed flashcard and matching sessions.
Run `supabase/learning_inventory.sql` in the Supabase SQL Editor to create the
separate inventory tables and custom-session RPCs. This migration does not
alter existing tables. Student-generated quizzes are listed from existing
saved-quiz data; flashcards and matching activities use the new inventory.
Run `supabase/learning_inventory_favorites.sql` as well to enable persisted
favorites for personal inventory activities. Inventory also supports title
search and groups results under quizzes, flashcards, and matching games.

Deploy the Edge Functions with the Supabase CLI:

```sh
supabase functions deploy extract-source-text
supabase functions deploy generate-quiz
supabase functions deploy generate-true-or-false
supabase functions deploy generate-flashcards
supabase functions deploy generate-matching
supabase functions deploy pdf-generation
```

The `pdf-generation` study-handout function accepts a custom session token, up
to 200 characters of context, and optional title/term/definition hex colors.
It generates a detailed, prose-first handout with section overviews,
subsection explanations, and key terms. The Flutter app validates and previews
the structured response, then creates the downloadable PDF on the client.
Deploy the function after adding the required
`GEMINI_API_KEY_1`–`GEMINI_API_KEY_5` and `GROQ_API_KEY_1`–`GROQ_API_KEY_3`
secrets.

Run `supabase/learning_streak.sql` in the Supabase SQL Editor to enable profile
login-date highlights and consecutive-day streak counts. The migration records
future logins and backfills dates from existing custom sessions. It also
records student active-learning days through the
`record_user_activity_day(p_session_token text)` RPC. Re-run this script if
that RPC is missing; it reloads the PostgREST schema cache when complete.

Run `supabase/classrooms.sql` in the Supabase SQL Editor to enable instructor
classroom creation and listing. Classroom access is validated using the app's
custom session token, and each classroom receives a unique shareable code.
If this migration was already applied, run it again to enable the classroom
icon selection and dashboard stats RPC. It also prepares a classroom
membership table and student RPCs so students can join by code from their My
Classroom screen and instructor class counts reflect memberships. The
dashboard stats RPC counts unique students across classrooms owned by the
instructor. It also enables instructor classroom deletion. After applying the
quiz and classroom-activity migrations below, the same RPC returns distinct
posted-quiz counts and each classroom's student count, distinct posted-quiz
count, and average quiz-attempt score. Instructor and student classroom lists
also include each classroom's student and posted-activity counts for the class
overview cards.

Run or re-run `supabase/classroom_activities.sql` after `classrooms.sql` and
`quiz_attempts.sql` to enable saved instructor quiz drafts, scheduled
classroom activities, activity listings, and student submissions. Classroom
activities allow instructors to set a total attempt limit (default 2); student
attempts are attributed to the classroom and activity, and the limit is
enforced by the database. Instructors can remove a quiz posting from a
classroom without deleting its saved quiz, while student recent activity
includes classroom quiz attempts and their classroom names. Existing attempts
are associated with an activity only when their classroom and schedule match
exactly one activity.

Run `supabase/instructor_classroom_students.sql` after `classrooms.sql`,
`classroom_activities.sql`, and `quiz_attempts.sql` to enable the instructor
classroom roster. Instructors can review each student's completed activity
count, average quiz score, attempt count, and join date, and remove students
from a classroom. Removing a student preserves existing quiz attempts.

Run `supabase/instructor_reports.sql` after `custom_auth.sql`,
`classrooms.sql`, `quiz_attempts.sql`, and `classroom_activities.sql` to enable
the instructor Reports screen. It summarizes classrooms and student quiz
performance and provides account details, overall quiz statistics, and quiz
generation counts for each enrolled student. Student details include the same
Accuracy, Retention, Improvement, Consistency, and Focus radar chart as the
student dashboard. Re-run it to enable the dashboard student follow-up panel;
it groups each student once across their classrooms and flags quiz averages
below 60% or started classroom quizzes they have not completed.

Run `supabase/instructor_learning_materials.sql` after `custom_auth.sql`,
`quiz_attempts.sql`, and `classroom_activities.sql` to enable the instructor
Learning Materials library. Instructors can review saved quizzes, post them to
selected classrooms with an availability window and attempt limit, or delete
them. Quizzes can be sorted by recency, name, or question count and organized
into named folders. Deleting a quiz also removes its classroom activity
postings; student quiz attempt records are retained.

The instructor dashboard includes a personal task list saved on the
current device for each instructor. Tasks support due dates, notes, priorities,
completion tracking, and overdue or due-today/tomorrow dashboard alerts. These
are in-app reminders shown on the dashboard, not background push notifications.

Run `supabase/student_notifications.sql` after the learner-points, learning
streak, weekly leaderboard, classroom, and classroom-activity migrations to
enable the student notification bell. It shows daily LP and streak rewards,
streaks of at least three days that ended, quiz LP reward breakdowns, last
week's final leaderboard rank, classroom activity posts, activities due within
24 hours, and classroom join/removal events. Notifications are kept for 90
days, support marking unread items as read, and the removal trigger records
future classroom removals.

Run `supabase/instructor_notifications.sql` after `custom_auth.sql`,
`classrooms.sql`, `classroom_activities.sql`, and `quiz_attempts.sql` to enable
the instructor notification bell. It reports student quiz submissions with
their score, new classroom memberships, and activities due within 24 hours
with a reminder to notify students. Submission and join notifications are
kept for 90 days, and notifications support marking unread items as read.

The quiz-generation function reads `GEMINI_API_KEY_1` through
`GEMINI_API_KEY_6` from Edge Function secrets and rotates keys on transient
Gemini failures. It tries `gemini-3.8-flash` first, then falls back through
`gemini-3.7-flash`, `gemini-3.6-flash`, `gemini-3.5-flash-lite`,
`gemini-3.5-flash`, `gemini-3.1-pro-preview`, and `gemini-3-flash-preview`.
Gemini 2.5 models are intentionally excluded. Keep these keys out of the
Flutter app. All three functions validate the app's custom session token; they do
not use Supabase Auth JWTs. PDF and DOCX text is extracted by
`extract-source-text` before it is sent to Gemini. TXT files are decoded by the
app. Quiz sources may be PDF, DOCX, or TXT files up to 3 MB. Scanned PDFs
without selectable text require OCR before they can be used.
