---
name: reverse-engineering-competitors
description: Use when you need a deep first-hand teardown of a competitor's product — its screens, UX/UI, engineering, and monetization — especially when a live logged-in account is available to explore, or when the goal is an exhaustive reference to inform what to build.
---

# Reverse-Engineering Competitors (deep, live)

## Overview
Produce a build-grade teardown of a competitor by combining a **first-hand authenticated crawl**
with an **adversarially-verified public research fan-out**, persisted to a durable doc so you never
re-crawl. Core principle: **the crawl finds the surface — observe EVERYTHING, then verify before you
trust it.**

## The one decision that shapes everything: the access split
Split targets by what actually reaches the data:
- **Authenticated screens** (behind login) → only YOU (main agent) can see them, via the user's live
  browser session (browser MCP). Inherently **sequential, single-driver.** This is the crown-jewel data.
- **Public surfaces** (marketing, pricing, docs, reviews, other competitors) → **fan out to subagents /
  a Workflow.** Subagents and headless browsers start logged-OUT — never point them at authed screens.

## Completeness gate (enumerate & COUNT — or you WILL claim "done" too early)
Before you claim ANY teardown complete, maintain a written CHECKLIST that **enumerates and counts
every distinct interactive surface** of the target: every nav item · sub-tab · filter dropdown ·
modal / popup · account & settings menu · quick-action · empty & error state · public marketing page.
Two status columns per row: **OPENED?** and **REFERENCED?** (in the durable doc).
- **The teardown is DONE only when every enumerated surface is OPENED (actually clicked into — "seen
  in a menu" does NOT count) AND REFERENCED.** Report the count (e.g. "31/34 opened").
- **"Exhaustive" / "every menu" is a BANNED claim until the checklist reads 100%.** If you skipped
  one, name exactly which and why, and mark it OPENED=no — never round up to "complete."
- **Incompleteness cascades.** Downstream work (resource-matching, design, build) inherits every gap,
  and a single missed surface can change the strategy — e.g. a referral modal that quietly reveals the
  competitor's real unit economics (placement-fee %), or a settings pane that reveals the data model.
  Enumerate first so nothing silently drops.
- **360º per surface.** A surface is "REFERENCED" only when captured from every angle it warrants:
  **UX** (the flow / interaction) · **UI** (layout, components, design tokens) · **Backend** (network /
  API / data-model / stack signals) · **Strategy** (why it exists — monetization, growth/virality,
  trust) · **How-it-works** (the mechanic, understood well enough to rebuild it). A screenshot alone is
  not a reference.
- **Reliability:** prefer **direct URL navigation** to routes + **element-reference clicks** (locate by
  `find`, click by `ref`) over pixel coordinates, and open a **fresh tab** if the renderer degrades —
  coordinate-guessing on a worn tab silently misses and fakes "coverage."
- **TOUCH EVERY element — actually click it.** Every button, tab, toggle, dropdown, card, icon, and
  quick-action, not just the containers. "I saw the button" ≠ "I clicked it." Buttons reveal states,
  modals, sub-screens, and backend calls (e.g. a "Call" button that opens a voice UI and connects to a
  named voice provider) that you CANNOT infer from the surface. Only firing it tells you what it does.
  **"Everything" means LITERALLY everything** — every button, link, tab, toggle, dropdown option, card,
  icon, avatar, quick-action, empty state, error state, and keyboard shortcut, plus the network call
  each one fires. NO surface is "too minor" to open: the minor ones (a referral modal that reveals the
  placement-fee %, a settings toggle, a "Call" button that reveals the voice provider) are exactly
  where the business model and the backend stack hide. If you have not clicked it, it is NOT done.

### DETERMINISTIC enforcement (prose rules get rationalized away — this HAS happened; remove the judgment call)
The checklist has exactly **two** per-surface states. There is NO third state:
- `[x]` **OPENED + REFERENCED** (actually clicked + captured 360º), or
- `[ ]` **GAP** (literally anything that is not the above).

**There is no "identified", "trivial", "low-signal", "minor", "boilerplate", or "flag-if-you-want-it"
status. Every un-opened surface is a `[ ]` GAP — full stop.** Predicting a surface is "low-value" is
forbidden: you cannot know a surface's value before opening it (a "minor" Privacy page held a
competitor's ENTIRE backend — Supabase + Neon — and the operator's identity; a "trivial" referral modal
held the placement-fee %). The cost of opening one more thing is tiny; the cost of a silent gap is a
wrong strategy.

**Banned vocabulary while any `[ ]` remains:** "exhaustive", "complete", "comprehensive", "100%",
"fully mapped", "identified", "low-signal", "trivial", "diminishing returns". Report the **count**
(e.g. `27/34 opened — 7 GAPs left`), never an adjective.

**Mechanical self-check — run before EVERY status/completeness sentence:** re-scan the checklist; if any
`[ ]` remains, you are NOT done — state the exact remaining count and keep firing. Never round up.

| Rationalization (verbatim ones actually used) | Reality |
|---|---|
| "it's trivial / low-signal / boilerplate" | You can't know until you open it — the "minor" Privacy page held the whole backend. |
| "I can infer what it does" | Inference isn't opening. Only firing reveals the modal, the network call, the copy. |
| "the session is long / diminishing returns" | Length is not a completeness argument. Fire it, or report it as a GAP — never round up. |
| "I'll mark it identified and move on" | "Identified" is not a state. It is a GAP. |
| "flag if you want each one fired" | Don't offload the rule to the user. The rule is: fire it. |

**Red flags — STOP, you are rationalizing:** about to write "exhaustive/complete/identified" · proposing
to "note" a surface instead of clicking it · citing session length or effort to skip a click · asking
the user whether the trivial ones are "worth it." Every one means: **open it.**

## Method
1. **Authenticated crawl (you + browser MCP).** Sweep EVERY nav item AND every sub-tab, modal, filter
   dropdown, and the **account/settings menus** — not just the obvious screens. The long tail (settings,
   privacy, referral, billing, saved/watchlist, filter panels) is where the real IA + business model
   live. Per screen capture: **IA** (nav + screen inventory) · **UX patterns** · **engineering signals**
   (network requests, console, framework/stack, data shapes via the network/JS tools) · **microcopy/
   voice** · **design tokens** (color, type, spacing, radius, icons). Interact fully **with explicit
   user permission** — click, type, drive their agent, test flows and error/empty states.
   **Harvest the live backend too** (this is how they *execute*, not just what they show): fingerprint
   the stack via JS globals + script `src`s (framework, auth, analytics, CMP, error-monitoring, ad
   pixels, feature-flags) and read the **network requests** (API endpoints, data shapes, whether
   RSC / GraphQL / REST, static-cached vs live-query). Note the data model the app exposes.
2. **Public fan-out (Workflow).** One agent per competitor doing a deep product + engineering + pricing
   teardown, each finding **adversarially verified by a second agent** (try to refute pricing/stack/
   traction claims). Add a **business-model / regulatory** track. Return compact schema'd summaries;
   write bulk to disk.
3. **Sequence resource matching AFTER the teardown** — you cannot pick which libraries or patterns to
   reuse before you've seen the UX *and* the backend you're emulating. Cover BOTH: **frontend**
   components (grounded in the visual teardown) AND **backend execution patterns / libraries**
   (grounded in the live backend fingerprint — how they scrape, store, orchestrate agents, serve the
   data plane), plus any of the competitor's own open-source repos/docs. Run it as a subagent fan-out.
4. **Persist a durable teardown doc**: menu inventory + UI/UX design tokens + engineering signals +
   monetization + the strategic seam. This is the reference that kills the need to re-crawl.
5. **Synthesize**: landscape map (name the camps), monetization read, the defensible seam, concrete
   product-surface recommendations.

## Quick reference
| Need | Tool |
|---|---|
| Authed screens | main-agent browser MCP (sequential — subagents can't log in) |
| Public breadth + verify | Workflow: fan-out → adversarial verify → synthesize |
| Bulk content | write to disk; agents return paths + schema'd summaries |
| Stack / API signals | network-requests + console + JS-eval on the live page |

## Cautions (learned live)
- **Hold the line on irreversible / outbound actions** — real applications or messages to third
  parties, purchases, settings changes, logout, delete. Do them only on explicit per-action user
  permission; otherwise capture the flow up to the confirm button and stop.
- **RAM / OOM:** screenshots bloat the parent context and heap. Chunk fan-out (3–4), compact returns to
  disk, check `free -h` before a big Workflow; a schema'd Workflow is safer than raw agents.
- **`save_to_disk` may not persist** (verify with a `find`); if it doesn't, the durable reference is a
  written design-token spec, not a pixel gallery — or the user captures the shots (they're logged in).
- **A persistent-agent chat column makes `get_page_text` re-dump the whole history** every call — prefer
  screenshots + targeted `read_page` for repeated captures.
- **Drag-drop via synthetic events often no-ops** (HTML5 DnD needs real mouse steps) — note the mechanic
  instead of fighting it.

## Common mistakes
- Skimming the main nav items and calling it done — you miss the sub-tabs / settings / modals, which are
  most of the app and most of the business model.
- **Claiming "exhaustive / every menu" when you only *catalogued* surfaces from the nav without opening
  them.** This is the cardinal sin: it cascades gaps into every downstream step and misreports the work
  as complete. Gate on the enumerate-and-count checklist; report the count, not an adjective.
- Sending subagents at logged-in screens (they see nothing).
- Picking components before seeing the UX.
- Trusting a single research pass without an adversarial verify.
- Narrating findings only in chat — nothing persists; write the durable doc as you go.
