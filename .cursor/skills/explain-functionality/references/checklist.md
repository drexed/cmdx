# Explanation Quality Checklist

Verify every item before delivering the explanation to the user.

## 1. Completeness

- [ ] **Intent stated first.** The explanation opens with why the code exists, not what it does mechanically.
- [ ] **All inputs identified.** Parameters, instance state, context keys, globals, env vars — nothing omitted.
- [ ] **All outputs identified.** Return values, mutations, signals, side effects — nothing omitted.
- [ ] **Branching paths covered.** Every conditional / early return / guard clause accounted for.
- [ ] **Dependencies classified.** Explicit, implicit, runtime, and ordering dependencies listed.
- [ ] **Side effects surfaced.** State mutations, I/O, flow control, observer notifications all flagged.

## 2. Accuracy

- [ ] **Code over docs.** If YARD docs and behavior disagree, the explanation follows the code.
- [ ] **No invented behavior.** Every claim can be traced to a specific line in source.
- [ ] **Edge cases grounded.** Listed assumptions are derived from the code, not hypothetical.

## 3. Clarity

- [ ] **Concrete examples.** Data shapes use real or realistic values, not abstract placeholders.
- [ ] **Line references included.** Key statements reference file path and line number.
- [ ] **Consistent terminology.** Uses the CMDx vocabulary table from SKILL.md without mixing synonyms.
- [ ] **Appropriate depth.** Simple code gets a brief explanation; complex flows get the full template.

## 4. Navigability

- [ ] **Template structure followed.** Sections match `assets/explanation-template.md` ordering.
- [ ] **Flow diagram present (if multi-file).** Call chains across files include a visual trace.
- [ ] **No filler.** Every sentence conveys information the reader didn't already have.
