---
name: rag-sync
description: End-of-session review and sync of learnings to the personal LightRAG knowledge graph
version: 1.0.0
model: sonnet
triggers:
  - /rag-sync
  - sync memories
  - push learnings
---

# RAG Sync — End-of-Session Personal Memory Sync

Review what happened this session and push non-obvious learnings to your personal LightRAG knowledge graph. Run before ending a productive session.

## Workflow

### Step 1: Review the session

Scan the conversation for items worth persisting. Look for:

- **Decisions** — architecture choices, tool selections, approach changes
- **User corrections** — "don't do X", "always do Y", preference changes
- **Config changes** — new env vars, port changes, server settings
- **Project updates** — status changes, new goals, deadline shifts
- **Debugging insights** — root causes found, non-obvious fixes
- **New relationships** — connections between systems, people, or projects

### Step 2: Filter ruthlessly

Remove anything that:
- Is already in the codebase (code, comments, configs)
- Is in git history (commits, diffs, blame)
- Was already stored via `/rag-remember` this session
- Is ephemeral (task progress, temp files, current branch state)
- Is a duplicate of something already in the knowledge graph

### Step 3: Format entries

Format each item using the `/rag-remember` format:
```
[TYPE] Title — YYYY-MM-DD

What: ...
Why: ...
Files: ... (if applicable)
```

### Step 4: Confirm with user

Present the list of items to store. Example:

> **Ready to sync 3 items to personal memory:**
> 1. [DECISION] Switched auth from JWT to session tokens — 2026-04-01
> 2. [FEEDBACK] User prefers single bundled PRs for refactors
> 3. [CONFIG] LightRAG project instance moved to port 9625
>
> **Proceed? (y/n)**

Wait for user confirmation before inserting.

### Step 5: Insert each item

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
      file_source: 'DESCRIPTION_HERE',
      text: 'CONTENT_HERE'
    })
  });
  console.log('Status:', res.status);
})();
"
```

### Step 6: Report

Summarize what was synced:
> **Synced 3 items to personal LightRAG.**

## Quality bar

Only store things that would **save 5+ minutes in a future session**.

**Good examples:**
- "The user's Mac Mini SSH requires BindAddress because Tailscale hijacks outbound sockets"
- "User prefers integration tests over mocked tests after a prod migration incident"

**Bad examples:**
- "Ran npm install successfully"
- "Fixed a typo in line 42 of app.js"
- "The build passed"

## Infrastructure

- **Server**: `YOUR_LIGHTRAG_HOST:YOUR_PERSONAL_PORT`
- **Auth**: Bearer token from `/auth-status` (guest/disabled mode)
- **Env var**: `LIGHTRAG_SERVER_URL`
