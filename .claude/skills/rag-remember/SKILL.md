---
name: rag-remember
description: Store a fact, decision, or observation into the personal LightRAG knowledge graph immediately
version: 1.0.0
model: sonnet
triggers:
  - /rag-remember
  - remember this
  - save this to memory
---

# RAG Remember — Store to Personal Knowledge Graph

Store a specific fact, decision, or observation into your personal LightRAG knowledge graph. Use mid-session when something worth remembering comes up.

## Formatting rules

Format each entry as:

```
[TYPE] Title — YYYY-MM-DD

What: Brief description of the fact or decision
Why: The reasoning or context behind it
Files: Relevant file paths (if applicable)
```

### Entry types

| Type | Use for |
|------|---------|
| `DECISION` | Architecture choices, tool selections, approach decisions |
| `FEEDBACK` | User corrections, preferences, "do this / don't do that" |
| `CONFIG` | Server settings, env vars, ports, credentials (NO actual secrets) |
| `PROJECT` | Project status, goals, deadlines, stakeholders |
| `PERSON` | People, roles, contact preferences, working styles |
| `REFERENCE` | URLs, docs, external resources, where to find things |
| `INSIGHT` | Debugging lessons, performance findings, non-obvious learnings |

## How to store

```bash
node -e "
const BASE = process.env.LIGHTRAG_SERVER_URL || 'http://YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT';
(async () => {
  const auth = await fetch(BASE + '/auth-status').then(r => r.json());
  const token = auth.access_token;
  const res = await fetch(BASE + '/documents/text', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    },
    body: JSON.stringify({
      file_source: '[TYPE] Title — YYYY-MM-DD',
      text: 'Full content here with What/Why/Files structure'
    })
  });
  const data = await res.json();
  console.log('Status:', res.status);
})();
"
```

## After inserting

- Confirm to the user: "Stored: [TYPE] Title"
- Do NOT dump the raw API response
- If the insert fails, tell the user and suggest trying again

## What NOT to store

- **Ephemeral task details** — current conversation context, in-progress work steps
- **Code from the codebase** — it's already in the repo; store the *decision*, not the code
- **Duplicates** — query first if unsure whether something is already stored
- **Credentials or secrets** — never store API keys, passwords, tokens
- **Git history** — use `git log` / `git blame` instead

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT`
- **Auth**: Bearer token from `/auth-status` (guest/disabled mode)
- **Env var**: `LIGHTRAG_SERVER_URL`
