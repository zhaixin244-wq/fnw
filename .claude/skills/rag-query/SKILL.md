---
name: rag-query
description: Query the personal LightRAG knowledge graph for persistent memory across sessions
version: 1.0.0
model: sonnet
triggers:
  - /rag-query
  - what do you know about
  - do you remember
---

# RAG Query — Personal Knowledge Graph

Query your personal LightRAG knowledge graph to recall decisions, preferences, project context, and learnings from past sessions.

## Query Modes

| Mode | When to use | What it does |
|------|------------|--------------|
| `hybrid` (default) | Most queries | Combines local entity relationships + global topic summaries |
| `local` | "What's related to X?" | Traverses entity relationships from specific nodes |
| `global` | "What do you know about topic Y?" | Summarizes across all documents on a topic |
| `naive` | Simple keyword lookup | Basic text search, fastest but least intelligent |

## How to query

### Full query (returns answer)

```bash
node -e "
const BASE = process.env.LIGHTRAG_SERVER_URL || 'http://YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT';
(async () => {
  const auth = await fetch(BASE + '/auth-status').then(r => r.json());
  const token = auth.access_token;
  const res = await fetch(BASE + '/query', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    },
    body: JSON.stringify({
      query: 'QUERY_HERE',
      mode: 'hybrid'
    })
  });
  const data = await res.json();
  console.log(JSON.stringify(data, null, 2));
})();
"
```

### Context-only query (returns raw context for Claude to synthesize)

```bash
node -e "
const BASE = process.env.LIGHTRAG_SERVER_URL || 'http://YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT';
(async () => {
  const auth = await fetch(BASE + '/auth-status').then(r => r.json());
  const token = auth.access_token;
  const res = await fetch(BASE + '/query', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    },
    body: JSON.stringify({
      query: 'QUERY_HERE',
      mode: 'hybrid',
      only_need_context: true
    })
  });
  const data = await res.json();
  console.log(typeof data === 'string' ? data : JSON.stringify(data, null, 2));
})();
"
```

## Response format

When presenting results to the user:
- Be concise — summarize, don't dump raw JSON
- Cite the source type when relevant (e.g., "from a stored decision on 2026-03-15")
- Flag potentially stale information (anything >30 days old)
- If no results found, say so clearly — don't fabricate

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT`
- **Auth**: Bearer token from `/auth-status` (guest/disabled mode)
- **Env var**: `LIGHTRAG_SERVER_URL`
