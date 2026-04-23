---
name: rag-setup-project
description: Set up LightRAG persistent memory for a Cursor project with MCP configuration
version: 1.0.0
model: sonnet
triggers:
  - /rag-setup-project
  - add memory to this project
  - setup project rag
---

# RAG Setup Project — Configure LightRAG for a Cursor Project

Set up a project-level LightRAG knowledge graph instance for the current Cursor project. Creates the MCP configuration so Claude Code can query and store project-specific memory.

## What this does

1. Creates `.cursor/mcp.json` in the project root with the LightRAG MCP server entry
2. Merges with existing MCP config if other servers are already configured
3. Optionally seeds the graph with project context (README, package.json, architecture docs)

## Setup steps

### 1. Create or merge MCP config

If `.cursor/mcp.json` does NOT exist:

```bash
node -e "
const fs = require('fs');
const config = {
  mcpServers: {
    'lightrag-projects': {
      command: 'npx',
      args: ['-y', 'lightrag-mcp@latest'],
      env: {
        LIGHTRAG_URL: 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT',
        LIGHTRAG_API_KEY: process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY'
      }
    }
  }
};
fs.mkdirSync('.cursor', { recursive: true });
fs.writeFileSync('.cursor/mcp.json', JSON.stringify(config, null, 2));
console.log('Created .cursor/mcp.json');
"
```

If `.cursor/mcp.json` already exists, merge:

```bash
node -e "
const fs = require('fs');
const existing = JSON.parse(fs.readFileSync('.cursor/mcp.json', 'utf-8'));
existing.mcpServers = existing.mcpServers || {};
existing.mcpServers['lightrag-projects'] = {
  command: 'npx',
  args: ['-y', 'lightrag-mcp@latest'],
  env: {
    LIGHTRAG_URL: 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT',
    LIGHTRAG_API_KEY: process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY'
  }
};
fs.writeFileSync('.cursor/mcp.json', JSON.stringify(existing, null, 2));
console.log('Merged lightrag-projects into existing .cursor/mcp.json');
"
```

### 2. Update .gitignore

Suggest adding `.cursor/` to `.gitignore` if not already present:

```bash
node -e "
const fs = require('fs');
const gitignore = fs.existsSync('.gitignore') ? fs.readFileSync('.gitignore', 'utf-8') : '';
if (!gitignore.includes('.cursor')) {
  fs.appendFileSync('.gitignore', '\n# Cursor IDE config\n.cursor/\n');
  console.log('Added .cursor/ to .gitignore');
} else {
  console.log('.cursor/ already in .gitignore');
}
"
```

### 3. Optionally seed the graph

If the user wants to seed the project graph with existing docs:

```bash
node -e "
const fs = require('fs');
const BASE = 'http://YOUR_LIGHTRAG_HOST:YOUR_PROJECT_PORT';
const API_KEY = process.env.LIGHTRAG_API_KEY || 'YOUR_API_KEY';

const files = ['README.md', 'package.json', 'ARCHITECTURE.md', 'CLAUDE.md']
  .filter(f => fs.existsSync(f));

(async () => {
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf-8');
    await fetch(BASE + '/documents/text', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY
      },
      body: JSON.stringify({
        file_source: '[SEED] ' + file + ' — project bootstrap',
        text: text.slice(0, 10000)
      })
    });
    console.log('Seeded:', file);
  }
  console.log('Done. Seeded ' + files.length + ' files.');
})();
"
```

## After setup

- Restart Claude Code to pick up the new MCP config
- Use `/rag-project-query` to query project memory
- Use `/rag-project-remember` to store project-specific knowledge
- Use `/rag-project-sync` at end of session to persist learnings
