---
name: debate
description: "Use when performing cross-model adversarial review of plans, architectures, or code. Triggers on 'debate', '辩论', '跨模型', '对手评审', 'adversarial review', '外部模型', 'cross-model'. Calls external LLM (Codex/Gemini/Kimi/GLM/MiMo/Claude) to challenge your plan with up to 3 rounds of adversarial iteration."
user_invocable: true
---

# /debate - Cross-Model Adversarial Review

Invoke an external LLM to adversarially challenge a plan, bug diagnosis, or codebase. You (Claude) are the orchestrator - the reviewer is a **different model** running as a read-only subprocess. Cross-model diversity is the point: different model families catch different blind spots.

## Invocation

```
/debate                    - plan review (default), uses first available provider
/debate debug              - debugging review mode
/debate review             - code review (recent changes via git diff)
/debate review src/lib/    - code review of specific path
/debate --provider codex   - Codex CLI / ChatGPT (recommended for diversity)
/debate --provider gemini  - Gemini CLI
/debate --provider claude  - Claude CLI (same-family fallback)
/debate --provider kimi    - Kimi CLI (Moonshot AI, kimi-k2)
/debate --provider glm     - GLM (Zhipu AI, glm-5.1) via curl
/debate --provider mimo    - MiMo (Xiaomi, mimo-v2.5-pro) via curl
```

**Provider selection order** (when no `--provider` flag):
1. `codex` - if Codex CLI is installed (cross-model, recommended)
2. `gemini` - if Gemini CLI is installed (cross-model)
3. `kimi` - if Kimi CLI is installed (cross-model, Chinese LLM)
4. `glm` - if `ZHIPUAI_API_KEY` env var is set (cross-model, Chinese LLM)
5. `mimo` - if `MIMO_API_KEY` env var is set (cross-model, Chinese LLM)
6. `claude` - always available as fallback (same-family, less diverse)

To auto-detect, check which CLI binaries exist: `command -v codex`, `command -v gemini`, `command -v kimi`. For curl-based providers (glm, mimo), check env vars: `ZHIPUAI_API_KEY`, `MIMO_API_KEY`. Use the first one found in the order above.

## Instructions

When the user invokes `/debate`, follow these steps exactly.

### Step 0: Parse Arguments

Parse the invocation for:
- **Mode**: `review` keyword -> code review mode. `debug` keyword -> debug mode. Otherwise -> plan mode.
- **Review target** (review mode only): Any path after `review` (e.g., `src/lib/inngest/`). If none, use recent git diff.
- **Provider**: `--provider codex`, `--provider gemini`, `--provider kimi`, `--provider glm`, `--provider mimo`, or `--provider claude`. Default: auto-detect (first available in order: codex -> gemini -> kimi -> glm -> mimo -> claude).

**Path validation (review mode only):** If a path is provided:
1. Resolve it to an absolute path: `RESOLVED=$(realpath -- "$TARGET" 2>/dev/null)`
2. Verify it is under the repo root: `[[ "$RESOLVED" == "$(git rev-parse --show-toplevel)"* ]]`
3. If validation fails -> stop and tell the user: "Path must be inside the repository."
4. Always double-quote the path in all subsequent commands: `"$TARGET"`

### Step 1: Identify the Subject

**Plan mode (default):**
- Look at your recent conversation context for a plan you wrote or are writing.
- If in plan mode (ExitPlanMode pending), use the current plan draft.
- If no plan is found, ask the user: "I don't see a plan to review. Want me to review a specific file or the most recent plan?"

**Debug mode (`/debate debug`):**
- Look at your recent conversation for a bug diagnosis or proposed root cause.
- If none found, ask the user to describe the bug and their current hypothesis.

**Review mode (`/debate review [path]`):**
- If a path is provided - that path is the review target (after validation in Step 0).
- If no path - get recent changes. Use this priority order:
  1. `git diff --cached` - staged changes (if non-empty)
  2. `git diff` - unstaged changes (if non-empty)
  3. `git diff HEAD~1 HEAD` - last commit diff (if HEAD~1 exists)
  4. `git show HEAD` - first commit (fallback for repos with a single commit)
- No plan or bug needed - the code itself is the subject.

### Step 2: Assemble Context Pack

Create a secure temp directory with restricted permissions:
```bash
umask 077
DEBATE_DIR=$(mktemp -d /tmp/debate.XXXXXX)
```

All debate artifacts go inside `$DEBATE_DIR/`. The restrictive umask ensures all files are created with `600`/`700` permissions automatically - no separate `chmod` needed.

Files:
- `$DEBATE_DIR/context.md` - assembled context pack
- `$DEBATE_DIR/review.txt` - reviewer output (created by redirection)
- `$DEBATE_DIR/stderr.txt` - reviewer stderr
- `$DEBATE_DIR/revised.md` - revised plan (rounds 2+, plan/debug only)

Write `$DEBATE_DIR/context.md` with these sections:

#### Always Include: Architecture Brief (Dynamic)

Read the architecture brief from the skill folder:

1. Look for `architecture-brief.md` in the same directory as this skill file (e.g., `.claude/skills/debate/architecture-brief.md`).
2. If found, include its full content as:
```markdown
# Context: Project Architecture (from architecture-brief.md)

[Full content of architecture-brief.md]
```
3. If not found, warn the user: "No architecture-brief.md found in the debate skill folder. The reviewer will have less context. Create one from the template to improve review quality." Then include a minimal fallback:
```markdown
# Context: Project Architecture

No architecture brief provided. The reviewer should explore the codebase to understand the project structure.
```

#### Conditionally Include: Domain Context

Scan the `domain-context/` subdirectory of the skill folder for domain context files:

1. List all `*.md` files in `domain-context/` (e.g., `.claude/skills/debate/domain-context/`).
2. **Skip** files whose names start with `_` (these are templates, not active context).
3. For each remaining file, read its YAML frontmatter to extract:
   - `name` - display name for the domain
   - `triggers.paths` - list of path prefixes (e.g., `src/api/`, `src/models/`)
   - `triggers.keywords` - list of keywords (e.g., "endpoint", "auth", "pipeline")
4. Match triggers against the plan/diagnosis/review-target text:
   - **Path match:** Any trigger path appears as a substring in the subject text.
   - **Keyword match:** Any trigger keyword appears (case-insensitive) in the subject text.
5. For each matched file, include its full content (below the frontmatter) as:
```markdown
# Domain Context: [name from frontmatter]

[Full content of the file, excluding frontmatter]
```

If no domain context files exist or none match, skip this section silently.

#### Always Include: The Subject

**Plan mode:**
```markdown
# Plan Under Review

IMPORTANT: Review ONLY this plan. Do not explore the codebase looking for other issues.

[The full plan text]
```

**Debug mode:**
```markdown
# Bug Diagnosis Under Review

IMPORTANT: Review ONLY this diagnosis. Do not explore the codebase looking for other bugs.

## Symptoms
[What the user/you observed]

## Proposed Root Cause
[The current hypothesis]

## Relevant Code
[Code snippets or file references relevant to the diagnosis]
```

**Review mode:**
```markdown
# Code Review Target

Code area to review: [path or "recent changes"]

IMPORTANT: Focus your review on the specified files/paths. You have read-only access to explore them thoroughly.

[If git diff: include the diff output]
[If path: list the key files in the path]
```

### Step 3: Write Context File

Use the Write tool to create `$DEBATE_DIR/context.md` with the assembled content. No separate `chmod` needed - the umask from Step 2 handles permissions.

### Step 3.5: Preflight Confirmation

Before invoking the reviewer, display a preflight message:

**For plan/debug modes:**
```
Starting debate: [plan|debug] review via [provider] ([model])
Estimated max cost: ~$1.50 (3 rounds x $0.50/round)
Proceed? [Y/n]
```

**For review mode:**
```
Starting debate: code review via [provider] ([model])
Estimated cost: ~$0.50 (single round, no revision loop)
Proceed? [Y/n]
```

Wait for user confirmation. If the user declines, clean up (`rm -rf "$DEBATE_DIR"`) and stop.

### Step 4: Invoke the Reviewer

**IMPORTANT:** The reviewer must be read-only. It challenges the plan - it does NOT modify code.

**Shell safety rules (apply to ALL providers):**
1. **Never interpolate plan/diagnosis/review text into shell arguments.** Always write content to a temp file and use input redirection.
2. **Always use input redirection** (`< "$file"`) instead of `cat file |` to avoid masking file-read errors behind a pipeline.
3. **Always redirect stdout** to `$DEBATE_DIR/review.txt` so the output is captured for parsing.
4. **When constructing bash commands, use heredocs with quoted delimiters** (`<<'EOF'`) to prevent variable expansion in prompt text.
5. **Use `set -o pipefail`** in any bash invocation that still uses pipes.

**Design principle:** You (Claude) are the orchestrator. The reviewer should ideally be a **different model family** - this is what makes the review adversarial. Claude reviewing Claude's work catches fewer blind spots than GPT or Gemini reviewing Claude's work. The providers below are listed in recommended order.

**Round 2+ (all providers):** Session resume is intentionally avoided - it's fragile across providers. Instead, assemble a fresh context pack for each round:

1. Write the revised plan/diagnosis to `$DEBATE_DIR/revised.md` using the Write tool.
2. Rebuild `$DEBATE_DIR/context.md` with:
   - The original architecture brief and domain context (unchanged)
   - The revised plan/diagnosis (replacing the original)
   - A new section: `# Prior Review Feedback` containing the reviewer's previous output
3. Run a fresh invocation using the same Round 1 command, reading from the updated `$DEBATE_DIR/context.md`.

---

#### Codex CLI Provider (recommended)

**Why recommended:** GPT-5.2 is a different model family from Claude. Cross-family review catches architectural blind spots that same-family models share.

**Round 1:**

For Codex, the review prompt must be prepended to the context file (no `--append-system-prompt`). When using Codex provider, include the review prompt at the top of `$DEBATE_DIR/context.md` before writing it.

```bash
codex exec \
  -m gpt-5.2 \
  -s read-only \
  - < "$DEBATE_DIR/context.md" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

Note: The `-` argument tells Codex to read the prompt from stdin, which is redirected from the context file.

**Install:** `npm install -g @openai/codex` + `OPENAI_API_KEY` env var. If `codex` is not found, tell the user to install it. If the reviewer returns a 401 or auth error, stop and tell the user to run `codex login`.

---

#### Gemini CLI Provider

**Why useful:** Gemini is yet another model family. Running the same review through Gemini after Codex provides a third perspective. Particularly strong on data flow and API design issues.

**Round 1:**

Like Codex, the review prompt must be prepended to the context file. When using Gemini provider, include the review prompt at the top of `$DEBATE_DIR/context.md` before writing it.

```bash
gemini \
  -m gemini-3-pro \
  < "$DEBATE_DIR/context.md" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

**Install:** `npm install -g @anthropic-ai/claude-code@latest` is not needed - check `command -v gemini`. Requires `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) env var. If `gemini` is not found, tell the user to install the Gemini CLI. If auth fails, tell the user to check their API key.

**Note:** Gemini CLI may have different flags than shown here. If the command fails, check `gemini --help` for the correct invocation syntax and adjust accordingly. The pattern is always: read context from stdin, write review to stdout, redirect stderr.

---

#### Claude CLI Provider (same-family fallback)

**Why fallback:** Claude reviewing Claude's own work provides less adversarial diversity than a different model family. Use this when no other provider is installed - it still catches real bugs, just with more shared blind spots.

**Round 1:**
```bash
env -u CLAUDECODE claude -p \
  --model sonnet \
  --allowedTools "Read,Grep,Glob" \
  --append-system-prompt "$(cat <<'SYSPROMPT'
[INSERT REVIEW PROMPT FROM STEP 4a/4b/4c BELOW]
SYSPROMPT
)" \
  --output-format text \
  --max-budget-usd 0.50 \
  < "$DEBATE_DIR/context.md" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

No extra install needed - Claude CLI is available in any Claude Code session. Requires `env -u CLAUDECODE` to allow nested invocation.

---

#### Kimi CLI Provider (Moonshot AI)

**Why useful:** Kimi (kimi-k2) is a Chinese LLM with strong reasoning and code understanding. Cross-family diversity from Western models; excels at Chinese-language context and long-context reasoning.

**Round 1:**

Kimi CLI supports `--print` mode for non-interactive use, reading from stdin.

```bash
kimi print \
  -m kimi-k2 \
  --output-format text \
  < "$DEBATE_DIR/context.md" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

**Install:** `pip install kimi-cli` or from [Moonshot AI](https://platform.moonshot.cn/). Requires `MOONSHOT_API_KEY` env var or `kimi login`. If `kimi` is not found, tell the user to install it. If auth fails, tell the user to run `kimi login`.

---

#### GLM Provider (Zhipu AI, via curl)

**Why useful:** GLM-5.1 (Zhipu AI) is a leading Chinese LLM with strong logical reasoning. Different model family from both Western and other Chinese LLMs, providing maximum review diversity.

**Round 1:**

GLM uses OpenAI-compatible API. The review prompt must be prepended to the context file.

```bash
curl -s --max-time 120 \
  -H "Authorization: Bearer $ZHIPUAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
with open('$DEBATE_DIR/context.md') as f:
    content = f.read()
print(json.dumps({
    'model': 'glm-5.1',
    'messages': [{'role': 'user', 'content': content}],
    'temperature': 0.3,
    'max_tokens': 8192
}))
")" \
  "https://open.bigmodel.cn/api/paas/v4/chat/completions" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

**Install:** No CLI needed - uses curl + OpenAI-compatible API. Requires `ZHIPUAI_API_KEY` env var. Get your key at [open.bigmodel.cn](https://open.bigmodel.cn/). If `ZHIPUAI_API_KEY` is not set, tell the user to set it.

---

#### MiMo Provider (Xiaomi, via curl)

**Why useful:** MiMo-v2.5-pro (Xiaomi) is a Chinese LLM optimized for code and technical reasoning. Another model family for maximum cross-model diversity.

**Round 1:**

MiMo uses OpenAI-compatible API. The review prompt must be prepended to the context file.

```bash
curl -s --max-time 120 \
  -H "Authorization: Bearer $MIMO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
with open('$DEBATE_DIR/context.md') as f:
    content = f.read()
print(json.dumps({
    'model': 'mimo-v2.5-pro',
    'messages': [{'role': 'user', 'content': content}],
    'temperature': 0.3,
    'max_tokens': 8192
}))
")" \
  "https://api.xiaomi.com/v1/chat/completions" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"
```

**Install:** No CLI needed - uses curl + OpenAI-compatible API. Requires `MIMO_API_KEY` env var. Get your key at [Xiaomi AI Platform](https://ai.xiaomi.com/). If `MIMO_API_KEY` is not set, tell the user to set it.

### Step 4a: Review Prompt - Plan Mode

Prepend this to the context file content (or use as --append-system-prompt for Claude CLI):

```
You are a senior engineer reviewing an implementation plan for a production system. Your job is to find problems, not validate.

The context below includes the project's architecture and relevant domain knowledge. Use it to ground your review.

Challenge the plan on:
1. **Security**: Missing auth checks, exposed endpoints, injection vectors, missing RLS policies, leaked secrets
2. **Data integrity**: Schema conflicts with existing tables, race conditions, missing constraints, orphaned records, state drift between services
3. **Concurrency**: Background jobs that could run in parallel unsafely, missing idempotency keys, stale reads, duplicate processing
4. **Edge cases**: What happens when external APIs fail? Empty states? Rate limits hit? Partial failures mid-pipeline?
5. **Architecture**: Is this the simplest approach? Does it create unnecessary tech debt? Does it conflict with existing patterns?

For each issue found, provide:
- **What's wrong** (specific, with file paths or table names when possible)
- **Why it matters** (concrete failure scenario, not hypothetical hand-waving)
- **Suggested fix** (actionable - not "consider adding" but "add X to Y")

End your review with exactly one of:
VERDICT: APPROVED
VERDICT: REVISE issues=[number] critical=[number]
```

### Step 4b: Review Prompt - Debug Mode

```
You are a senior debugging engineer reviewing a bug diagnosis for a production system. Your job is to challenge the diagnosis, not confirm it.

The context below includes the project's architecture and relevant domain knowledge. Use it to check if the proposed root cause actually makes sense given how the system works.

Challenge the diagnosis on:
1. **Alternative causes**: What else could produce these exact symptoms? List at least 2 alternatives with reasoning.
2. **Assumptions**: What is the developer assuming that might not be true? Check against the architecture context.
3. **Missing evidence**: What specific log, query, or test would confirm or rule out this cause?
4. **Scope**: Could this be a symptom of a deeper issue? Is the developer treating a leaf when the root is elsewhere?

For each challenge, provide:
- **The assumption being challenged**
- **Why it might be wrong** (with reference to architecture/code when possible)
- **How to verify** (specific command, query, or test - not "check the logs")

End your review with exactly one of:
VERDICT: APPROVED
VERDICT: REVISE issues=[number] critical=[number]
```

### Step 4c: Review Prompt - Code Review Mode

```
You are a senior engineer performing a code review on a production system.
Your job is to find real problems that would cause failures in practice.

You have read-only access to the codebase. Explore the target files thoroughly.

Review the code for:
1. **Correctness**: Logic bugs, off-by-one errors, incorrect assumptions, broken control flow
2. **Error handling**: Unhandled failures, silent swallows, missing retries, unclear failure modes
3. **Data integrity**: Race conditions, missing constraints, incorrect queries, state inconsistencies
4. **Performance**: N+1 queries, missing indexes, unnecessary round-trips, expensive operations in hot paths
5. **Security** (for production-facing code): Auth gaps, injection vectors, missing input validation

Prioritize issues that would cause real failures over theoretical concerns.
Do NOT flag issues that only matter in adversarial/multi-tenant contexts
unless the code actually runs in such an environment.

For each issue, provide:
- File path and line reference
- What is wrong
- Why it matters (concrete failure scenario)
- Suggested fix

End with:
VERDICT: issues=[number] critical=[number]
```

### Step 5: Error Handling and Verdict Parsing

After each invocation, apply these checks **in order**:

#### 5.1: Check Exit Code

The exit code must be captured in the **same Bash tool call** as the reviewer invocation. Each Bash tool call runs in a separate shell, so `$?` in a subsequent call is always 0.

Append `; echo "EXIT_CODE:$?"` to the invocation command. For example:
```bash
env -u CLAUDECODE claude -p \
  --model sonnet \
  ... \
  < "$DEBATE_DIR/context.md" \
  > "$DEBATE_DIR/review.txt" \
  2> "$DEBATE_DIR/stderr.txt"; echo "EXIT_CODE:$?"
```

Parse `EXIT_CODE:N` from the Bash tool output. If N is non-zero:
- Read stderr from `$DEBATE_DIR/stderr.txt`
- Display to user: "Reviewer process failed (exit code N): [stderr contents]"
- Clean up (`rm -rf "$DEBATE_DIR"`) and stop. Do NOT loop.

#### 5.2: Check Output is Non-Empty

- Check: `[[ -s "$DEBATE_DIR/review.txt" ]]`
- If output file is empty or missing - **stop immediately**.
- Display to user: "Reviewer produced no output. This may indicate an auth issue or rate limit."
- Clean up and stop.

#### 5.3: Parse Verdict

1. Read the reviewer's full output from `$DEBATE_DIR/review.txt`.
2. **Strip markdown formatting** from output: remove `**`, `*`, `` ` ``, `~~` characters.
3. **Ignore content inside code blocks** (between ``` fences).
4. **Case-insensitive** match for lines containing `VERDICT:`.

**For plan/debug modes:**
5. Match pattern: `VERDICT:\s*(APPROVED|REVISE)` (case-insensitive). For REVISE, also extract `issues=(\d+)\s+critical=(\d+)` from the same line.
6. Take the **last** occurrence that matches - earlier occurrences may be analysis/discussion.
7. If no verdict found - treat as `REVISE`, warn user: "Reviewer output had no clear verdict - treating as REVISE."

**For review mode:**
5. Match pattern: `VERDICT:\s*issues\s*=\s*(\d+)\s+critical\s*=\s*(\d+)` (case-insensitive).
6. Extract the issue count and critical count.
7. If no verdict found - present the full output as findings anyway (the review is still useful without a formal verdict line).

#### 5.4: Act on Verdict

**For review mode (`/debate review`):** There is no revision loop. Present findings and skip to Step 6. Optionally ask: "Want me to file these findings as a GitHub issue?"

**For plan/debug modes:**

**If APPROVED:**
- Display to user: summary of what the reviewer checked, confirmation that no critical issues were found.
- Clean up temp dir.
- Done.

**If REVISE:**
- Display the reviewer's feedback to the user in a clear format.
- Address each issue: revise the plan/diagnosis based on the feedback.
- Show the user what changed (diff-style summary).
- Write the revised plan to `$DEBATE_DIR/revised.md` (use the Write tool).
- Re-invoke the reviewer with the revised version (Step 4, round 2+).

**Round counting:**
- Round 1 = initial review.
- Rounds 2-3 = revision rounds.
- Maximum 3 rounds total (1 initial + 2 revisions).
- Early exit: If any round returns APPROVED, stop immediately - do not use remaining rounds.
- After round 3, stop regardless of verdict and present:
  - The current plan state
  - Unresolved issues from the reviewer
  - Your recommendation on whether to proceed or not

### Step 6: Present Results

After the loop completes, present a summary:

```
## Debate Summary

**Mode:** Plan Review | Debug Review | Code Review
**Provider:** Codex CLI (gpt-5.2) | Gemini CLI (gemini-3-pro) | Claude CLI (sonnet)
**Rounds:** N
**Final verdict:** APPROVED | REVISE issues=N critical=N | issues=N critical=N (review mode)

### Changes Made During Review
- [List of substantive changes to the plan/diagnosis]

### Unresolved Concerns (if any)
- [Issues the reviewer raised that you chose not to address, with reasoning]
```

For review mode, replace "Changes Made" with "Findings" - the full list of issues found.

### Step 7: Cleanup

Remove the entire temp directory. This must run even on early exit (error in Step 5.1/5.2).

```bash
rm -rf "$DEBATE_DIR"
```

This is a single command that cleans up all artifacts - context, output, stderr, and any revised plans - regardless of how many rounds ran.

## Orchestrator Lessons (Practical Notes)

These notes come from live testing and should inform how you execute the skill:

1. **Shell quoting:** When constructing bash commands, always use file-based I/O (write to temp file, use input redirection). Never interpolate plan text into command arguments. Plan text containing `$()`, backticks, quotes, or newlines **will** break or inject.
2. **Input redirection over pipes:** Use `command < "$file"` instead of `cat "$file" | command`. Input redirection avoids masking file-read errors behind a pipeline (no need for `pipefail`).
3. **Codex stdin:** `codex exec` reads stdin when `-` is passed as the prompt argument. Always use `codex exec -m model -s read-only - < "$file"` to pass context.
4. **Context framing matters:** If the context pack doesn't clearly frame what to review, the reviewer will explore the codebase and review whatever it finds. The "IMPORTANT: Review ONLY this" directive is essential for plan/debug modes.
5. **Auth can expire silently:** Codex CLI tokens expire. If the reviewer returns a 401, stop and tell the user to run `codex login`. For Claude CLI, check for `ANTHROPIC_API_KEY` errors.
6. **Nested session blocker:** Claude CLI refuses to run inside Claude Code due to the `CLAUDECODE` env var. All Claude CLI invocations **must** use `env -u CLAUDECODE` to unset it.
7. **Concurrent debates:** Avoid running multiple debates in parallel with the same provider. While session resume has been removed, concurrent debates still compete for rate limits and may cause confusing interleaved output.

## Adding a New Provider

Any CLI tool that can read a prompt from stdin and write a review to stdout can be a provider. To add one, add a new provider block in Step 4 following this template:

```
#### [Provider Name] CLI Provider

**Why useful:** [What perspective this model family brings]

**Round 1:**
[Command - must use input redirection from $DEBATE_DIR/context.md, redirect stdout to review.txt, stderr to stderr.txt]

**Install:** [Package manager command] + [env var name].
```

The provider contract:
1. **Input:** Read context from `$DEBATE_DIR/context.md` via stdin (`< "$file"`)
2. **Output:** Write review to stdout (redirected to `$DEBATE_DIR/review.txt`)
3. **Errors:** Write errors to stderr (redirected to `$DEBATE_DIR/stderr.txt`)
4. **Read-only:** The reviewer must not modify any files in the repository
5. **Review prompt:** Prepend to context file (or use system prompt if the CLI supports it)

No code changes needed - just a new text block in this skill file. Then add the provider name to the auto-detect order in the invocation section if it should be preferred over existing providers.
