# Hermes Word Morphology Matrix – Examples

This file provides concrete examples of how Hermes Agent should respond when this skill is active.

---

## Example 1: Single base word – "happy"

**User input:**
> Analyze the morphology of "happy" and related words.

**Hermes response (outline):**

### Base word: happy

1. Short introduction.
2. Python/pandas code that constructs a DataFrame with rows for: `happy`, `unhappy`, `happiness`, `unhappiness`, `happily`, `happier`, `happiest`.
3. Rendered table with all required columns.
4. List of 5–10 key derived words with breakdowns.
5. Teaching note about `un-`, `-ness`, `-ly`, comparative/superlative, and `y → i` spelling change.
6. Mini practice exercise (3–5 questions) with an answer key.

---

## Example 2: Two base words – "teach" and "kind"

**User input:**
> Show morphology matrices for "teach" and "kind".

**Hermes response (outline):**

### Base word: teach

- Matrix rows might include: `teach`, `teacher`, `teaching`, `teachable`, `re-teach`, `overteach`, `teachings`.

### Base word: kind

- Matrix rows might include: `kind`, `unkind`, `kindness`, `unkindness`, `kindly`.

For each base word, Hermes repeats the full pattern: matrix → derived list → teaching note → exercise.

---

## Example 3: Vague request

**User input:**
> Can you show me some English morphology?

**Hermes behavior:**

- Do **not** ask for more details.
- Select 1–2 common base words (for example, `happy` and `play`).
- Produce full outputs for each base word following the template in this skill.

---

These examples are intended as high-level guides. All detailed formatting rules and column definitions are in `SKILL.md`.