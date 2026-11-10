# Understanding generation speed

The performance view shows three ways to describe how long a model attempt
took. The numbers are in **milliseconds** (`1,000 ms = 1 second`).

## How each number is computed

| Column | Computation | Plain meaning |
|---|---|---|
| `avg_latency_ms` | Add the included attempt times, then divide by how many attempts there are. | The average time. A few very slow attempts can pull it up. |
| `p50_latency_ms` | Sort attempt times from shortest to longest, then find the 50th percentile (the middle). | About half of attempts took this long or less. |
| `p90_latency_ms` | Sort attempt times from shortest to longest, then find the 90th percentile. | About 90% of attempts took this long or less; the slowest 10% took longer. |

### Worked example

Suppose ten attempts took these times, in milliseconds:

`1,000, 2,000, 3,000, 4,000, 5,000, 6,000, 7,000, 8,000, 9,000, 10,000`

| Metric | Calculation | Result |
|---|---|---:|
| Average | `(1,000 + 2,000 + ... + 10,000) ÷ 10` | `5,500 ms` |
| P50 | Middle of the sorted list: average the 5th and 6th values, `(5,000 + 6,000) ÷ 2` | `5,500 ms` |
| P90 | 90th percentile falls 90% of the way from the 9th value to the 10th: `9,000 + 0.9 × (10,000 - 9,000)` | `9,900 ms` |

The database uses continuous percentiles (`percentile_cont`), so P50 or P90
can fall between two observed attempt times. The average can differ from P50
when the times are uneven; unusually slow attempts affect the average strongly.

## What these numbers measure

Each number measures **one model attempt**, from the backend sending a request
to that model until that attempt finishes. They do not measure the full time
the person waits for the entire generation request. For example, retries or
trying another model can make the full request take longer than any one
attempt.

Cancelled attempts are left out of the average, P50, and P90 because they were
stopped before completing. Other finished attempts, including failed attempts,
are included.

The view groups these measurements by **content type**, **API-key label**, and
**model**. This lets you compare the same model across API keys or content
types. The API-key label is a name such as `GROQ_API_KEY_2`, not the secret key.

## Quick comparison tip

Use **P50** to understand a typical attempt and **P90** to see how slow things
can be for most attempts. Use the **average** as an overall summary, but check
P50 and P90 too: the average alone can hide a mix of fast and very slow calls.
