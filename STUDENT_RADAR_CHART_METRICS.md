# Student dashboard spider chart: how the stats are calculated

The chart has five spokes. Each spoke is a percentage from 0 to 100, except
**Improvement**, which is first calculated as a score change and then converted
to the chart's 0-to-100 scale.

The chart compares:

| Color | Series |
|---|---|
| Orange | Current stats |
| Purple | Past 7 days |

Dates use the student's local calendar day. A date window includes both its
first day and today.

## Metric calculations

| Spoke | Calculation | Current stats (orange) | Past 7 days (purple) |
|---|---|---|---|
| **Accuracy** | Add correct answers across included attempts, divide by the total number of questions in those attempts, then multiply by 100. | Attempts from the last 28 days, or since account creation if the account is newer. | Attempts from the last 7 days. |
| **Retention** | For each quiz with at least two included attempts, average the percentages from that quiz's two most recent included attempts. Then average those quiz averages. Each quiz has equal weight. | All available attempts; each quiz's two most recent attempts overall. Quizzes with fewer than two attempts are skipped. | Attempts from the last 7 days; quizzes with fewer than two attempts in that window are skipped. |
| **Improvement** | For each quiz with at least two included attempts, calculate each score change between consecutive attempts in time order and average those changes. Then average the per-quiz results. A change is measured in percentage points. | All available attempts. | Attempts from the last 7 days; quizzes with fewer than two attempts in that window are skipped. |
| **Consistency** | Count distinct days with one or more quiz attempts, divide by the number of eligible days, then multiply by 100. Multiple quizzes on the same day count as one active day. | Active days in the last 28 days, or since account creation if the account is newer. | Active days in the last 7 days. |
| **Focus** | For each quiz with an included attempt, find its earliest included attempt. Add correct answers from those first attempts, divide by their total questions, then multiply by 100. | The earliest attempt for each quiz across all available history. | The earliest attempt for each quiz within the last 7 days. |

### Example: accuracy

Suppose the included attempts contain 18 correct answers out of 24 questions:

`18 ÷ 24 × 100 = 75% accuracy`

Accuracy is weighted by questions: an attempt with more questions contributes
more than an attempt with fewer questions.

### Example: retention

Suppose two quizzes have these two-most-recent-attempt averages:

- Quiz A: `(60% + 80%) ÷ 2 = 70%`
- Quiz B: `(90% + 100%) ÷ 2 = 95%`

Retention is `(70% + 95%) ÷ 2 = 82.5%`. The two quizzes count equally, even if
they have different numbers of questions.

### Example: improvement

Suppose one quiz's attempts score `50%, 70%, 65%`. Its consecutive changes are
`+20` and `-5` percentage points, so that quiz's improvement is:

`(+20 + -5) ÷ 2 = +7.5 percentage points per retry`

The chart maps improvement onto its 0-to-100 spoke like this:

`(improvement + 100) ÷ 2`, limited to the range 0–100.

| Average change per retry | Position on chart |
|---:|---:|
| `-100` points or less | `0` |
| `0` points (no change) | `50` |
| `+20` points | `60` |
| `+100` points or more | `100` |

Therefore, the Improvement spoke is a **scaled score change**, not the
percentage of questions answered correctly. A position above 50 means scores
generally rose; below 50 means they generally fell.

## How to read the shape

- A point farther from the center means a higher value on that spoke.
- The grid has four rings, representing 25%, 50%, 75%, and 100%.
- Accuracy, Retention, Consistency, and Focus are percentages with their usual
  meaning. Improvement uses the special scale described above.
- If there is not enough data to calculate a metric, it has no marker; the
  chart places that missing value at the center when drawing the shape.
- A value of `0%` is a real calculated zero. It is different from a metric that
  could not be calculated due to insufficient data.

## Implementation reference

The dashboard assembles the current and weekly values in
`lib/screens/home/student_home_screen.dart`. The calculations are implemented
in `lib/services/quiz_service.dart`; the axes, 0–100 scale, rings, and
Improvement conversion are drawn in
`lib/widgets/student_performance_radar_chart.dart`.
