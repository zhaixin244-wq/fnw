---
name: rag-project-sync
description: End-of-session review and sync of project-specific learnings to the project-level LightRAG graph
version: 1.0.0
model: sonnet
triggers:
  - /rag-project-sync
  - sync project memory
  - push project learnings
---

# RAG Project Sync — End-of-Session Project Memory Sync

Review what happened this session and push project-relevant learnings to the project-level LightRAG knowledge graph.

## Workflow

### Step 1: Review the session

Scan the conversation for project-specific items worth persisting:

- **Architecture decisions** — component design, data flow changes, API structure
- **Conventions established** — naming patterns, file organization, coding standards
- **Dependencies added/changed** — new packages, version bumps, API integrations
- **Config changes** — env vars, build settings, deployment config
- **Requirements clarified** — business rules, constraints, edge cases discovered
- **Gotchas found** — non-obvious behaviors, platform quirks, workarounds needed

### Step 2: Filter ruthlessly

Remove anything that:
- Is already in the codebase (code, comments, configs)
- Is in git history (commits, diffs)
- Was already stored via `/rag-project-remember` this session
- Is personal (not project-specific) — redirect to `/rag-sync` instead
- Is ephemeral (current branch state, temp files)

### Step 3: Format entries

Format each item using the `/rag-project-remember` format:
```
[TYPE] Title — YYYY-MM-DD

What: ...
Why: ...
Files: ... (if applicable)
```

### Step 4: Confirm with user

Present the list:

> **Ready to sync 2 items to project memory:**
> 1. [ARCHITECTURE] API routes use controller pattern with service layer — 2026-04-01
> 2. [CONVENTION] All database queries go through repository classes — 2026-04-01
>
> **Proceed? (y/n)**

Wait for confirmation before inserting.

### Step 5: Insert each item

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
      file_source: 'DESCRIPTION_HERE',
      text: 'CONTENT_HERE'
    })
  });
  console.log('Status:', res.status);
})();
"
```

### Step 6: Report

> **Synced 2 items to project LightRAG.**

## Quality bar

Only store things that would **save 5+ minutes in a future session** working on this project.

**Good examples:**
- "The payment service requires idempotency keys — without them, duplicate charges occur"
- "Tests must run against the staging database, not local SQLite (schema divergence)"

**Bad examples:**
- "Added a new component called UserCard"
- "Fixed lint errors"
- "Installed express"

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT`
- **Auth**: X-API-Key header (auth-enabled mode)
- **Env var**: `LIGHTRAG_API_KEY`
