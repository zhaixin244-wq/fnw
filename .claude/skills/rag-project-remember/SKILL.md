---
name: rag-project-remember
description: Store project-specific knowledge into the project-level LightRAG knowledge graph
version: 1.0.0
model: sonnet
triggers:
  - /rag-project-remember
  - remember this for the project
  - save project context
---

# RAG Project Remember — Store to Project Knowledge Graph

Store project-specific knowledge — architecture decisions, conventions, dependencies, and requirements — into the project-level LightRAG graph.

## Formatting rules

Format each entry as:

```
[TYPE] Title — YYYY-MM-DD

What: Brief description
Why: The reasoning or constraint behind it
Files: Relevant file paths (if applicable)
```

### Entry types

| Type | Use for |
|------|---------|
| `ARCHITECTURE` | System design choices, component structure, data flow |
| `CONVENTION` | Coding standards, naming patterns, file organization rules |
| `DECISION` | Technology choices, library selections, approach decisions |
| `DEPENDENCY` | External services, APIs, packages, version constraints |
| `CONFIG` | Environment setup, build config, deployment settings |
| `REQUIREMENT` | Business rules, constraints, acceptance criteria |
| `INSIGHT` | Performance findings, gotchas, non-obvious behaviors |

## How to store

```bash
node -e "
const BASE = 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT';
const API_KEY = process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY';
(async () => {
  const res = await fetch(BASE + '/documents/text', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY
    },
    body: JSON.stringify({
      file_source: '[TYPE] Title — YYYY-MM-DD',
      text: 'Full content here with What/Why/Files structure'
    })
  });
  console.log('Status:', res.status);
})();
"
```

## After inserting

- Confirm to the user: "Stored to project memory: [TYPE] Title"
- Do NOT dump the raw API response

## When NOT to use this

Use `/rag-remember` (personal graph) instead for:
- **User preferences** — working style, tool preferences, communication style
- **Cross-project knowledge** — things that apply to all projects
- **Personal context** — roles, responsibilities, machine config
- **People info** — contacts, working relationships

This skill is for things **specific to the current project** that wouldn't be relevant elsewhere.

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT`
- **Auth**: X-API-Key header (auth-enabled mode)
- **Env var**: `LIGHTRAG_API_KEY`
