---
name: rag-project-query
description: Query the project-level LightRAG knowledge graph for project-specific context and decisions
version: 1.0.0
model: sonnet
triggers:
  - /rag-project-query
  - project memory
  - query project context
---

# RAG Project Query — Project Knowledge Graph

Query the project-level LightRAG knowledge graph for architecture decisions, conventions, dependencies, and project-specific context.

## Query Modes

| Mode | When to use | What it does |
|------|------------|--------------|
| `hybrid` (default) | Most queries | Combines local entity relationships + global topic summaries |
| `local` | "What's related to X in this project?" | Traverses entity relationships from specific nodes |
| `global` | "What are the project conventions?" | Summarizes across all project documents |
| `naive` | Simple keyword lookup | Basic text search, fastest but least intelligent |

## How to query

### Full query

```bash
node -e "
const BASE = 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT';
const API_KEY = process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY';
(async () => {
  const res = await fetch(BASE + '/query', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY
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

### Context-only query

```bash
node -e "
const BASE = 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT';
const API_KEY = process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY';
(async () => {
  const res = await fetch(BASE + '/query', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY
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

When presenting results:
- Distinguish project memory from personal memory — prefix with "Project context:" when relevant
- Be concise — summarize, don't dump raw JSON
- Cite the source type (e.g., "from an architecture decision stored on 2026-03-20")
- Flag stale info (>30 days old)
- If no results, say so — don't fabricate

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT`
- **Auth**: X-API-Key header (auth-enabled mode)
- **Env var**: `LIGHTRAG_API_KEY`
- **Workspace**: Project-specific (separate from personal graph)
