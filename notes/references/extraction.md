# Extraction Rules

Split the conversation into these 8 buckets. Empty buckets are fine — drop them silently in output.

| Bucket | Includes |
|---|---|
| **Facts** | durable statements about systems, clients, prices, configurations |
| **Decisions** | "we chose X", "going with Y", trade-offs resolved |
| **Requirements** | client/project asks, scope, deliverables |
| **Action items** | who / what / due date if known |
| **Open questions** | unresolved items needing follow-up |
| **Risks** | known blockers, dependencies, exposure |
| **Ideas** | proposed approaches not yet decided |
| **Follow-ups** | "ping back next week", scheduled checks |

## Save

- final-state facts and outcomes
- decisions with rationale
- client preferences and constraints
- technical implementation details that would be hard to reconstruct
- pricing / scope / deadline statements
- explicit action items with owners

## Drop

- casual chatter, jokes, social pleasantries
- repeated/duplicate statements
- temporary confusion that was resolved later in the same conversation
- typo corrections
- live-debugging dead ends unless they explain the final fix
- unnecessary personal details

## Secrets — never save verbatim

If the conversation contains any of:

- passwords, API keys, tokens, JWT, private keys, SSH keys, certificates
- database connection strings with credentials
- session cookies

Then:

1. Do not write the secret value to any page.
2. Save only that "a credential of type X was discussed" if relevant to the note.
3. Add a Warning in the report recommending rotation.

## Topic key

Generate a short stable kebab-case `Topic` for the metadata header. Reuse it across related notes so dedupe and cross-linking work later. Examples: `<project-or-client>-<area>`, e.g. `acme-deployment`, `billing-model`, `auth-rewrite`.

## Tags

Specific only. Bad: `notes`, `meeting`, `general`. Good: actual project / client / system / topic identifiers from the conversation.
