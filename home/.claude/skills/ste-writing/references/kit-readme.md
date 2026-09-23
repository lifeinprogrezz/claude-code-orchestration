# The cure for AI slop is a 1986 aircraft manual - the kit

Everything the episode promises "in the description": the distilled STE skill,
the linter, and the full first-party test data. The skill, the linter, and the
data need nothing beyond Python 3.

## Files

| File | What it is |
|---|---|
| `ste-writing-skill.md` | The distilled ASD-STE100 agent skill, two modes: strict (procedures, error messages) and flavored (prose, no dictionary lockdown) |
| `ste-recurring-errors.md` | The spec's own list of the 39 most frequent writer errors, with approved replacements |
| `ste-lint.py` | The heuristic anti-slop linter - the machine-checkable subset of STE. Deterministic; the score delta between two texts is the signal |
| `experiment-results.md` | The cross-model test: 6 writing tasks x 4 conditions on Claude and gpt-5.5 |
| `experiment-results-openai.md` | Per-category detail for the gpt-5.5 run |
| `before-after-samples.md` | The real baseline-vs-STE outputs quoted in the episode |
| `run-openai.py` | The script we ran for the OpenAI side. Needs `prompts.json` and the four condition prompts, which were not published |

## Run the linter

```
python3 ste-lint.py your-draft.md            # flavored: general prose
python3 ste-lint.py --strict your-draft.md   # strict: adds the STE word set, counts em dashes
```

Score is violations per 100 words - lower is cleaner. Lint a draft, apply the
skill, then lint it again - the delta between the two scores is the signal.
Useful flags: `--json` for machine-readable output, `--fail-over N` to exit 1
when the score is over N (CI gates, pre-commit hooks).

The linter reports `score_version: 2`. Version 2 catches perfect tenses and
modal stacks, no longer counts adjectival participles ("the valve is closed")
as passive, and moves "provide" to the banned list. The headline numbers below
were measured with score v1 - this file's git history at the episode date. The
two versions score close but are not directly comparable.

## Use the skill

Claude Code: copy or symlink the kit into a skill directory, then ask for STE.

```
mkdir -p ~/.claude/skills/ste-writing
ln -s "$PWD/ste-writing-skill.md" ~/.claude/skills/ste-writing/SKILL.md
ln -s "$PWD/ste-lint.py" "$PWD/ste-recurring-errors.md" ~/.claude/skills/ste-writing/
```

Any other agent: paste `ste-writing-skill.md` into the system prompt or custom
instructions. The skill works without the linter; the linter closes the loop.

## The headline numbers

| Condition | Claude sonnet | gpt-5.5 |
|---|---|---|
| baseline | 4.36 | 3.54 |
| banned-words list | 4.21 (-3%) | 2.14 (-40%) |
| Orwell's 6 rules | 2.48 (-43%) | 1.69 (-52%) |
| STE skill | 1.12 (-74%) | 1.76 (-50%) |

Give the model a writing system and slop drops by half or more, on every model
tested. STE was best or tied-best. A banned-words list is the least reliable fix.

Not a certified STE checker. The judgment rules of ASD-STE100 need a human;
this covers the mechanical subset - which is where the slop lives. Unofficial
and not affiliated with ASD. ASD-STE100 is a registered EU trademark
(No. 017966390).

Spec: ASD-STE100 Issue 9, free at asd-ste100.org
