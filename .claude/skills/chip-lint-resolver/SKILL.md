---
name: chip-lint-resolver
description: Use when processing vc-spyglass lint log output to resolve violations. Maps lint rules to JMTAG execution levels, proposes RTL fixes or generates waive files. Triggered by keywords like spyglass, lint log, lint violation, JMTAG, waive file, lint rules.
---

# Chip Lint Resolver

Resolves vc-spyglass lint violations by mapping each rule to its JMTAG execution level, then producing RTL modification proposals or waive files.

## When to Use

- Processing vc-spyglass lint log output (`.log`, `.rpt`, `.out`)
- Need to map lint rule names to JMTAG execution standards
- Need to generate RTL fix proposals or waive files
- Debugging lint violations with wiki knowledge lookup

## Core Workflow

```
0. Load blackbox module list
1. Parse lint log → extract (rule_name, file, line, message) tuples
2. Check blackbox → if module is BLACKBOX, auto-waive all its violations
3. Map remaining rules → JMTAG level via reference table
4. For each JMTAG level, execute the corresponding action
5. Output: RTL modification proposal + waive file
```

### Step 0: Load Blackbox Module List

Read `blackbox-modules.md` (same directory as this SKILL.md) to load the blackbox module list.

A module is BLACKBOX if:
- Its module name matches an entry in the blackbox list, OR
- The violating file path contains a blackbox module name (e.g., `ip/ahb_slave/ahb_slave.v` matches blackbox entry `ahb_slave`)

Blackbox modules are typically:
- Third-party IP (not owned by the team)
- Pre-verified IP (already tape-out proven)
- Hard macros or analog wrappers
- Modules explicitly excluded from lint scope

If `blackbox-modules.md` is empty or missing, skip this step and process all violations normally.

### Step 1: Parse Lint Log

vc-spyglass log format (typical patterns):

```
Warning [<rule_name>] <file>:<line> <message>
Error [<rule_name>] <file>:<line> <message>
```

Extract: rule_name, severity, file path, line number, violation message.

If log format is unknown, ask user to paste a sample or specify format.

### Step 2: Filter Blackbox Violations

For each parsed violation, check if its module is in the blackbox list:

```
module_name ← extract from file path (e.g., "ahb_slave" from "ip/ahb_slave/ahb_slave.v")
if module_name in blackbox_list:
    → mark as BLACKBOX_WAIVED, skip JMTAG analysis
```

Output all blackbox-waived violations in a separate section of the waive file.

### Step 3: Map Rule → JMTAG

Lookup in `lint-jmtag-mapping.md` reference file (same directory as this SKILL.md).

```
rule_name → JM_E0/E1/E2/E3/Warning/Info/HARDEN
```

If a rule is not in the mapping table:
- Flag it as "unknown rule" in the output
- Ask user to classify it manually

### Step 4: Execute JMTAG Action

| JMTAG | Action | Output |
|-------|--------|--------|
| JM_E0 | **Mandatory fix.** LLM analyzes RTL, produces modification proposal | RTL fix in proposal doc |
| JM_E1 | **Mandatory fix.** LLM analyzes RTL, produces modification proposal | RTL fix in proposal doc |
| JM_E2 | **Mandatory fix.** LLM analyzes RTL, produces modification proposal | RTL fix in proposal doc |
| JM_E3 | **Conditional.** LLM checks if RTL has real issue. Fix if yes, waive if no | Fix or waive |
| JM_Warning | **Conditional.** LLM checks if RTL has real issue. Fix if yes, waive if no | Fix or waive |
| JM_Info | **Conditional.** LLM checks if RTL has real issue. Fix if yes, waive if no | Fix or waive |
| JM_HARDEN | **User confirmation.** Ask user if HARDEN or boundary issue, then analyze | Fix or waive (after user input) |

### Step 5: Generate Output

#### 5a. RTL Modification Proposal (`lint_fix_proposal.md`)

Structure:

```markdown
# Lint Fix Proposal

## Summary
- Total violations: N
- Blackbox waived: N (from BLACKBOX modules)
- Fix required: N (E0/E1/E2)
- Conditional: N (E3/Warning/Info)
- HARDEN: N
- Waived: N

## Fixes

### [JM_E0] <rule_name> — <file>:<line>
**Violation:** <message from log>
**Root Cause:** <analysis>
**Fix:**
```verilog
// Before
<original code>

// After
<fixed code>
```

### [JM_E3] <rule_name> — <file>:<line>
**Violation:** <message>
**Assessment:** <has real issue / no real issue>
**Action:** Fix / Waive
**Fix (if applicable):** ...
```

#### 5b. Waive File (`lint_waive.waiver`)

vc-spyglass waive file format:

```waiver
// Auto-generated waive file
// Date: YYYY-MM-DD

// === Blackbox Module Waives ===
waive -rule <rule_name> -file <file_path> -line <line_number> -message "BLACKBOX: <module_name> is in blackbox list (<reason>)"

// === Conditional Waives (E3/Warning/Info) ===
waive -rule <rule_name> -file <file_path> -line <line_number> -message "<reason>"
```

Waive reasons:
- BLACKBOX module: `"BLACKBOX: <module_name> is in blackbox list (<reason>)"`
- JM_E3/Warning/Info with no real issue: `"No functional impact, style/preference only"`
- JM_HARDEN confirmed not applicable: `"Not a HARDEN boundary, user confirmed"`
- False positive: `"False positive: <explanation>"`

### Step 6: Wiki Knowledge Lookup

For detailed rule information, query the wiki:

```
wiki query: "<rule_name> lint rule" or "<rule_name> SpyGlass"
```

Wiki provides:
- Rule definition and rationale
- Common violation patterns
- Standard fix patterns
- Related coding style rules

Use wiki knowledge to improve root cause analysis and fix quality.

## Output Files

| File | Purpose | Location |
|------|---------|----------|
| `lint_fix_proposal.md` | RTL modification proposals | Same dir as lint log |
| `lint_waive.waiver` | Waive file for vc-spyglass | Same dir as lint log |

## Reference

Lint rule → JMTAG mapping: `lint-jmtag-mapping.md` (274 rules, 7 JMTAG levels)
Blackbox module list: `blackbox-modules.md` (user-configurable, auto-waive)

## Common Errors

| Issue | Fix |
|-------|-----|
| Rule not in mapping table | Flag as unknown, ask user to classify |
| Log format unrecognized | Ask user for sample, or specify `--format` |
| JM_HARDEN without user input | Always ask user before deciding HARDEN |
| Waive E0/E1/E2 rules | Never waive E0/E1/E2 without explicit user override |
| Missing wiki knowledge | Proceed with general knowledge, note "wiki unavailable" |
| blackbox-modules.md empty/missing | Skip blackbox check, process all violations |
| Module name ambiguous | Match by both file path and module declaration |
