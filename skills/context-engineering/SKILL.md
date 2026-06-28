---
name: context-engineering
description: Use this skill when designing AI agent systems, optimizing context window usage, building multi-agent pipelines, writing tool descriptions, or diagnosing agent performance degradation. Covers context compression, degradation patterns, memory systems, multi-agent coordination, tool design, and harness engineering.
---

# Context Engineering

## Fundamentals

**Context = complete state at inference time:** system prompt + tool definitions + retrieved docs + message history + tool outputs.

**Optimization target:** tokens-per-TASK (total tokens to complete a task including re-fetch costs), NOT tokens-per-request. Aggressive compression that forces re-fetching costs more overall.

**U-shaped attention curve:** models attend strongly to beginning (system prompt) and end (recent messages). Middle degrades — critical info buried in the middle gets lost. Put important facts at edges, not buried.

**Quality > quantity:** 10k tokens of high-signal context beats 100k tokens of noise.

## Context Degradation Patterns (5 Types)

| Pattern | Signal | Mitigation |
|---|---|---|
| Lost-in-middle | Agent ignores facts stated mid-context | Move critical info to top or bottom |
| Poisoning | Contradictory info corrupts reasoning | Validate and deduplicate before loading |
| Distraction | Off-topic context pulls attention | Scope retrieval tightly to current task |
| Confusion | Similar but distinct concepts merged | Explicit labeling and separation |
| Clash | Two valid but conflicting contexts | Explicit priority ordering |

## Context Compression

**Handoff summary must preserve:** decisions made, files modified, risks identified, next actions — NOT a transcript.

```
decisions: [list of irreversible choices made]
files_modified: [paths + what changed]
open_risks: [things that could go wrong]
next_actions: [concrete next steps]
```

**Compression tiers:**
1. Observation masking: replace verbose tool output with a reference pointer, fetch on demand
2. Structured summarization: decisions + files + risks + next (4-field minimum)
3. Selective retention: keep instructions and outcomes, drop step-by-step reasoning

## Context Optimization

**KV cache:** identical prefix = cache hit = near-zero re-processing cost. Put stable content (system prompt, tool defs, long docs) at top; variable content (conversation) at bottom.

**Observation masking:** when tool output is large, write to file + load reference only. Fetch full content only when needed for the specific next step.

**Budget triggers:** define thresholds (e.g. >80% context = compact). Automate compaction before window exhaustion.

**Retrieval scoping:** retrieve only what's relevant to the current subtask, not the entire document.

## Memory Systems

**4 memory types:**
| Type | Scope | Implementation |
|---|---|---|
| In-context | Current session | Conversation + task state |
| External semantic | Cross-session | Vector/graph store |
| Episodic | Past interactions | Session summaries |
| Procedural | Persistent skills | SKILL.md files |

**Frameworks:**
- **Mem0:** vector store, fast semantic retrieval
- **Zep/Graphiti:** temporal knowledge graph, entity tracking over time
- **Letta:** structured in-context + archival + recall layers

**Temporal validity:** memories have expiry. Stale memories are worse than no memory (confidently wrong). Always verify memory against current state before acting.

## Multi-Agent Patterns

**Primary reason for sub-agents: context isolation**, NOT role anthropomorphization. Each agent has its own window — isolation prevents cross-contamination.

**When to use sub-agents:**
- Task decomposes into independent parallel subtasks
- Subtasks need different tool sets or system prompts
- Single agent context window is the bottleneck

**Coordination patterns:**
- **Supervisor/worker:** orchestrator delegates, workers return results, orchestrator synthesizes
- **Swarm:** peer agents, emergent coordination, shared goal
- **Pipeline:** sequential agents, each transforms output of previous

**Handoff discipline:** explicit structured handoffs — not "continue from conversation." Worker needs: task description + relevant context slice + expected output format.

**Single vs multi-agent:** start single. Add agents only when context isolation is genuinely needed.

## Tool Design

**Tool description is the contract** — agents infer intent from descriptions alone.

**Description must answer WHEN to call this** (not just what it does):
- Bad: "Gets user data."
- Good: "Retrieve a user's profile when you need their email, name, or account status — not for authentication checks."

**Schema design:**
- Required params: only what's always needed
- Optional params: configuration and overrides
- Enums: for constrained choices (never free-string where enum works)
- Every param needs a description

**Error messages must be actionable:**
- Bad: "Invalid input"
- Good: "Parameter `date` must be ISO 8601 (e.g. 2026-06-28). Received: '28/06/2026'."

**Tool catalog hygiene:** >10 overlapping tools = agent picks wrong half the time. Consolidate. Use verb-noun naming: `search_documents`, `create_task`, `update_user`.

## Harness Engineering (Autonomous Loops)

**Harness = control system around agent:** what it may edit, how it gets feedback, where it writes state, how failures recover, who approves irreversible actions.

**Locked vs editable surfaces:** metrics/rubrics = locked (agent cannot weaken them to pass). Code/content = editable. Never let an agent modify its own evaluation criteria.

**State machine for long runs:** explicit states (initialized → retrieved → evaluated → proposed → validated → done). Never hand-edit state files.

**Novelty gate:** before acting, check if this change has been tried before. Reject/revise ledger prevents re-discovering failed paths.

**Human approval boundary:** irreversible actions (push to prod, send email, delete data) require explicit approval each time. Authorization for one instance ≠ authorization for all instances.

**Durable logs:** append-only. Every decision, output, and failure. Required for audit and rollback.

## Evaluation

**Deterministic checks first** (syntax, format, schema) → model judges only where deterministic checks can't reach.

**LLM-as-judge bias mitigation:**
- Position bias: randomize order of options
- Verbosity bias: normalize length before judging
- Self-enhancement: don't use same model to judge its own outputs

**Pairwise >> absolute scoring:** models and humans are better at "A or B" than "score 1-10".

**Regression suites:** test on golden examples before shipping any change. Per-task effect sizes matter more than aggregate accuracy.

## Project-Level Decisions

**Task-model fit — LLMs are right when:**
- Output is natural language or structured text
- Quality can be judged by another model
- Failure is recoverable
- Cost per call is acceptable

**LLMs are wrong when:** exact computation needed, latency <100ms required, output must be deterministic.

**Pipeline shape:** Acquire → Prepare → Process → Parse → Render. Each stage has a clear input/output contract.

**Cost estimation:** `token_count × calls × (input_price + output_price)`. Always estimate before building. At scale, caching and compression change the economics dramatically.
