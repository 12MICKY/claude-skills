---
name: context-engineering
description: Use this skill when building AI agents, multi-agent systems, Claude Code tools, or optimizing LLM context — context window mechanics, KV cache strategy, compression techniques, degradation patterns, memory system design (Mem0/Zep/Letta), tool design principles, harness engineering for autonomous loops, and LLM evaluation methodology. Activate for any agent architecture, MCP server design, or AI system engineering task.
---

# Context Engineering

## Context Window Fundamentals

**Context = complete state at inference time:**
```
System prompt + Tool definitions + Retrieved documents + Message history + Tool outputs
```

**Optimization target:** tokens-per-TASK (total across the task), NOT tokens-per-request. Aggressive compression that forces re-fetching costs more overall.

**U-shaped attention curve:** models attend strongly to the beginning (system prompt) and end (recent messages). Middle degrades. Critical facts buried in the middle get ignored. Design context so:
- System prompt = stable instructions + role + constraints
- Recent messages = current task state
- Middle = historical context (summarize aggressively)

**Quality > quantity:** 10k tokens of high-signal context beats 100k tokens of noise. Noise crowds out attention budget and diffuses focus.

## Context Degradation Patterns

| Pattern | Signal | Mitigation |
|---|---|---|
| Lost-in-middle | Model ignores facts stated mid-context | Move critical info to top or bottom |
| Poisoning | Contradictory info corrupts reasoning | Validate and deduplicate before loading |
| Distraction | Off-topic context pulls attention wrong | Scope retrieval tightly to current subtask |
| Confusion | Similar but distinct concepts merged | Explicit labeling and clear separation |
| Clash | Two valid but conflicting instructions | Explicit priority ordering in system prompt |

**Treat degradation as an engineering problem** — it has measurable thresholds, not random failure.

## KV Cache Strategy

**Cache hit = near-zero cost** to re-process identical prefix tokens.

**Structure for maximum cache efficiency:**
```
[STABLE, CACHED]    ← system prompt, tool definitions, long reference docs
[VARIABLE, FRESH]   ← conversation history, current task context
```

Put stable content at the top; variable content at the bottom. Any change to cached prefix invalidates all subsequent cache entries.

**Anthropic prompt cache:** prefix up to 50k tokens. Cache TTL ~5 min. Savings: ~90% on cached input tokens.

```python
# Enable caching on system prompt (Anthropic SDK)
{
    "role": "system",
    "content": [{
        "type": "text",
        "text": "...long stable instructions...",
        "cache_control": {"type": "ephemeral"}
    }]
}
```

## Context Compression Techniques

**Tier 1 — Observation masking:**
When a tool returns large output, store it and load a reference:
```python
# Instead of putting 5000-token tool output in context:
result = run_tool()
save_to_file("result.json", result)
return "Result saved to result.json. Key finding: X"
```

**Tier 2 — Structured summarization:**
```
decisions: [list of irreversible choices made]
files_modified: [paths + what changed]
open_risks: [things that could go wrong]
next_actions: [concrete next steps]
```

**Tier 3 — Selective retention:**
Keep instructions and outcomes. Drop step-by-step reasoning from history.

**Budget trigger:** define a threshold (e.g., >80% context used) → automatically compact before exhaustion, not after.

## Memory System Design

**4 memory types:**

| Type | Storage | Scope | Example |
|---|---|---|---|
| In-context (working) | Token window | Current session | Conversation history |
| External semantic | Vector/graph DB | Cross-session | User facts, project state |
| Episodic | Summaries | Past sessions | "Last week we deployed X" |
| Procedural | Files/prompts | Persistent | Skill files, CLAUDE.md |

**Framework selection:**
- **Mem0** — vector store, fast semantic retrieval. No graph structure. Good for simple "remember user facts."
- **Zep/Graphiti** — temporal knowledge graph, entity tracking over time. Good for "what changed about X."
- **Letta** — structured in-context + archival + recall layers. Good for complex stateful agents.

**Temporal validity:** memories expire. Tag with creation timestamp + TTL. Stale confident memories are worse than no memory. Always verify memory against current file state before acting on it.

## Multi-Agent Patterns

**Primary reason for sub-agents: context isolation**, not role-playing. Each agent has its own clean window.

**When to use sub-agents:**
- Task decomposes into genuinely parallel, independent subtasks.
- Different subtasks need different tool sets or system prompts.
- Single agent context window is the actual bottleneck.

**Coordination patterns:**

| Pattern | When to use |
|---|---|
| Supervisor/worker | Orchestrator delegates, workers return structured results, orchestrator synthesizes |
| Swarm | Peer agents with shared goal, emergent coordination |
| Pipeline | Sequential agents, each transforms previous output |

**Handoff discipline:** workers need exactly:
```
1. Task description (what to do)
2. Relevant context slice (just what they need)
3. Expected output format (schema)
```

Not the full orchestrator trajectory. Over-sharing wastes tokens and confuses the worker.

**Latent briefing / KV cache sharing:** instead of re-transmitting full context to workers as text, share the KV cache representation filtered to what the worker needs. Reduces worker input cost without summarization loss.

## Tool Design Principles

**Tool description is the contract.** The model generates calls from description alone.

**Trigger-focused descriptions:**
```
Bad:  "Gets user data"
Good: "Retrieve a user's profile when you need their email, name, or account status"
```

**Schema design rules:**
- Required params: only for what's always needed.
- Optional params: for configuration/overrides.
- Enums for constrained choices (never free-string where enum works).
- Description on every param, not just the tool name.

**Actionable error messages:**
```
Bad:  "Invalid input"
Good: "Parameter `date` must be ISO 8601 format (e.g. 2026-06-29). Received: '29/06/2026'"
```

**Tool catalog hygiene:** >10 tools with overlapping purposes → model picks wrong half the time. Consolidate. Use verb-noun naming: `search_documents`, `create_task`, `update_user`.

**MCP namespacing:** `server_name__tool_name` convention prevents collision across servers.

## Harness Engineering (Autonomous Loops)

**Harness = control system around agent:** what it may edit, how it gets feedback, where state lives, how failures recover, who approves irreversible actions.

**Locked vs editable surfaces:**
- Metrics/rubrics = LOCKED (agent must not weaken its own evaluation criteria).
- Code/content = editable.
- Never let an agent modify its own evaluation criteria.

**State machine for long runs:**
```
initialized → retrieved → evaluated → proposed → validated → done
```
Each transition is logged. Never hand-edit state files mid-run.

**Novelty gate:** before acting, check if this exact change was tried before (rejection/revision ledger). Prevents re-discovering failed paths on loop iteration 12.

**Human approval boundary:** irreversible actions (push to prod, send email, delete data) require explicit approval each time. Authorization for one instance ≠ authorization for all instances.

**Durable logs:** append-only. Every decision, every output, every failure. Required for audit and rollback.

## LLM Evaluation Methodology

**Evaluation pipeline order:**
1. Deterministic checks (syntax, format, schema) — fast, cheap, no model needed.
2. Heuristic checks (length, keyword presence) — fast rules.
3. LLM-as-judge — only where deterministic checks can't reach.

**LLM-as-judge bias mitigation:**
- Position bias: randomize option order when comparing.
- Verbosity bias: normalize length before judging (longer ≠ better).
- Self-enhancement: don't use the same model to judge its own output.
- Calibrate rubrics with human baselines before trusting judge scores.

**Pairwise > absolute scoring:** "A or B?" is more reliable than "score 1-10."

**Required evaluation dimensions:**
- Correctness — is it factually right?
- Completeness — does it cover all required aspects?
- Grounding — no hallucination of sources/quotes?
- Format compliance — matches required schema/structure?
- Safety — no harmful output?

**Regression suites:** golden examples locked before any change. Accuracy is a misleading aggregate — look at per-task effect sizes and confusion matrix.

## Task-Model Fit

**LLMs are the right tool when:**
- Output is natural language or structured text.
- Quality can be judged by a model or human (not exact computation).
- Failure is recoverable (not irreversible operations at scale).
- Cost per call is acceptable for the task volume.

**LLMs are wrong when:**
- Exact computation required (use code).
- Latency < 100ms required (LLMs are too slow).
- Output must be perfectly deterministic (use deterministic algorithms).

**Single vs multi-agent:** start single. Add agents only when context isolation is genuinely needed, not as an architectural preference.

## Cost Optimization

**Cost = token_count × calls × (input_price + output_price)**

Always estimate before building. At scale, compression and caching change economics dramatically.

**High-ROI optimizations:**
1. KV cache for stable system prompt (90% savings on repeated prefix).
2. Prompt compression (remove verbose examples, use concise instructions).
3. Model right-sizing (Haiku for classification/routing, Sonnet for generation, Opus for complex reasoning).
4. Batch API for offline workloads (50% discount, async delivery).
5. Output length control (set `max_tokens` tight; verbose output = expensive).
