---
name: hermes-word-morphology-matrix
description: Build morpheme-focused English word morphology matrices using Python and pandas. Use when the user asks Hermes Agent to analyze word structure, prefixes, roots, suffixes, or to generate morphology tables, teaching notes, and practice exercises.
disable-model-invocation: true
---

# Hermes Word Morphology Matrix

## Purpose and Scope

This skill configures Hermes Agent to create morpheme-focused morphology matrices for one or more **English base words**, following the user's pedagogical specification.

Hermes should use this skill when the user:
- Mentions **word formation**, **morphology**, or **morpheme analysis**.
- Asks for **prefix–root–suffix breakdowns** or hyphenated segmentations (e.g., `un-happi-ness`).
- Wants **derivational families** built from a base word.
- Requests **tables, teaching notes, or practice exercises** about morphology.

The target audience is learners and teachers of English (intermediate+).

## Core Behavior

When this skill is active and the user provides one or more base words, Hermes must:

1. **Use Python for the matrix**
   - ALWAYS construct the morphology matrix using Python.
   - Prefer `pandas.DataFrame`.
   - Show the code used to build the DataFrame, then render the table in a clean, readable format.

2. **Focus on real, common English words**
   - Do **not** invent unattested forms.
   - If a form is real but infrequent, mark it as `rare/uncommon`.

3. **Prioritize derivational morphology**
   - Focus on prefixes/suffixes that change meaning or part of speech (e.g., `-ness`, `-able`, `un-`, `re-`).
   - Include inflectional forms (`-s`, `-ed`, `-ing`, `-er`, `-est`) only when they add learning value (e.g., demonstrate spelling changes, degree, or common patterns) or when the user explicitly asks.

4. **Segment at morpheme level**
   - Explicitly segment words with **hyphens** at morpheme boundaries: `un-happi-ness`, `teach-er`, `re-teach`.
   - Respect standard pedagogical segmentations; do not over-split roots.
   - When the spelling changes before a suffix (e.g., `happy → happi-ness`), show the morpheme boundary using the pedagogically useful form (`happi-ness`) and explain the spelling change in the notes.

5. **Avoid unnecessary questions**
   - If the user is vague (e.g., "show me morphology"), pick **1–2 very common base words** (like `happy`, `teach`, `play`, `kind`) and proceed.
   - Only ask for clarification if you truly cannot proceed (e.g., user wants an extremely specific set of words but is ambiguous).

6. **Batch handling**
   - When many base words are given, process them in **batches** (e.g., 2–3 per response) to keep the output readable.
   - Clearly label each section with a heading: `## Base word: happy`.

## Required Output Per Base Word

For each base word `W`, Hermes must output:

1. A **morphology matrix** (Python-generated table).
2. A **pedagogical follow-up** consisting of:
   - 5–10 key derived words (with breakdowns),
   - a short teaching note,
   - a mini practice exercise with answers.

### 1) Morphology Matrix Specification

#### Construction via Python

Hermes must:
- Write a short Python snippet that:
  - Imports `pandas`.
  - Builds a list/dict of rows.
  - Constructs a `pandas.DataFrame`.
- Use this **column schema** exactly (names may be localized only if the user explicitly requests another language):

- `Base / Root` – underlying base form (e.g., `happy`).
- `Morpheme Breakdown` – segmented word using hyphens (`un-happi-ness`).
- `Prefix(es) + meaning` – brief gloss of prefix(es), or `—`.
- `Root + meaning` – base/root plus a short meaning.
- `Suffix(es) + meaning` – brief gloss of suffix(es), or `—`.
- `Part of speech` – word class of this **derived form** (e.g., adjective, noun, verb, adverb; comparative, superlative when relevant).
- `Meaning shift` – concise explanation of how the meaning changes from the base.
- `Example words` – 1–3 example words that show the same affix pattern (may include the word itself).
- `Example sentence` – a simple, learner-friendly sentence containing this word.

Example row structure (for the root itself):

```python
{
    "Base / Root": "happy",
    "Morpheme Breakdown": "happy",
    "Prefix(es) + meaning": "—",
    "Root + meaning": "happy – feeling or showing pleasure",
    "Suffix(es) + meaning": "—",
    "Part of speech": "adjective",
    "Meaning shift": "Base meaning: feeling pleasure or contentment",
    "Example words": "happy, joyful, content",
    "Example sentence": "She feels happy today.",
}
```

After constructing the DataFrame, Hermes should print or display it, then reproduce the resulting table in the chat as a markdown table.

### 2) Pedagogical Follow-Up

Immediately after the matrix for base word `W`, Hermes must output:

#### a) 5–10 most useful derived words

- Choose the most pedagogically useful derivatives.
- For each, show:
  - The word.
  - Its morpheme breakdown (with hyphens).
  - A short gloss (one phrase, learner-friendly).

Format:

- `unhappy` → `un-happi` – "not happy; sad"
- `happiness` → `happi-ness` – "state of being happy"

If a form is rare, mark it clearly, e.g. `X (rare/uncommon)`.

#### b) Short teaching note

- 3–7 sentences.
- Explain:
  - What the main prefixes and suffixes do (meaning + part-of-speech change).
  - Any regular spelling patterns (e.g., `y → i` before `-ness`, `-ly`; consonant doubling, etc.).
  - How learners can transfer these patterns to new words.
- Keep tone neutral, supportive, and clear.

#### c) Mini practice exercise

- Design a **small** exercise focused on the same morphemes used in the matrix.
- Types of tasks you may choose (pick 1–2 styles per base word):
  - Morpheme identification (underline or list prefixes/root/suffix).
  - Matching word to meaning based on morphemes.
  - Fill-in-the-blank using correct derived forms.
- Provide:
  - Numbered questions.
  - An explicit answer key at the end.

Example pattern:

1. Break `unhappily` into morphemes and label each part.
2. Which suffix in `happiness` makes it a noun?
3. Choose the correct form to complete the sentence: "She was very ____ (happy/happiness/happily)."

**Answer key**:
1. `un-happi-ly` – `un-` (not), `happi` (root), `-ly` (adverb).
2. `-ness`.
3. `happy`.

## Morphological Accuracy

Hermes must:

- Prefer derivational patterns when choosing rows; avoid filling the table with only inflections unless explicitly asked.
- Use standard school-grammar segmentations; do not over-analyze Latinate roots unless clearly pedagogically useful and accurate.
- When a form is morphologically opaque but still useful (e.g., `understand`), treat it as a single root in this skill unless the user wants deeper historical/etymological detail.
- When segmentation is debatable, choose the mainstream pedagogical option and, if needed, note this briefly in `Meaning shift`.

Examples:
- `un-happy`, not `u-nhapp-y`.
- `teach-er`, `re-teach`.
- `happi-ness` (with note about `y → i`).

## Interaction Style

When this skill is active:

- Do **not** ask unnecessary questions; infer reasonable defaults.
- Keep explanations compact but clear.
- Use headings and lists to keep long answers readable.
- Avoid sensitive or offensive example content.
- Always include explicit morpheme breakdowns for every example and key derived form.

## Quick Reference Workflow for Hermes

When the user asks Hermes for morphology of one or more base words:

1. **Identify the base word(s)**.
2. **Choose 5–10 key family members** per base word (prioritize derivational forms).
3. **Write Python + pandas code** to build a DataFrame with the required columns.
4. **Render the table** in the chat in markdown form.
5. **List 5–10 key derived words** with breakdowns and glosses.
6. **Write a short teaching note** about observed patterns.
7. **Create a mini practice exercise** with an answer key, focused on the same morphemes.

Follow this workflow each time this skill is used.