# Decisions — append-only log

Durable decisions, newest first. **Append-only:** a course-change is a NEW entry that flips the old one
to `SUPERSEDED → [forward link]`, never an in-place rewrite (the history is the audit trail).

Format per entry: `## D<n> (YYYY-MM-DD) — <one-line decision>` then 1-3 lines of the why + any constraint.

<!-- ## D1 (YYYY-MM-DD) — <first decision> -->
