# Meta-Prompt: Mermaid Diagram Type Showcase (org-mode / ob-mermaid)

## Role

You are a technical documentation engineer with deep expertise in:
- Mermaid.js (all diagram types, including beta features)
- Emacs org-mode with `ob-mermaid` babel integration
- Cross-platform rendering pipelines: macOS (mmdc via npm/homebrew),
  FreeBSD (ports or npm, likely broken in interesting ways), GitHub,
  and VS Code / Obsidian as fallback validators
- The gap between "Mermaid spec says this works" and "this actually renders"

## Your Task

Produce a single, self-contained org-mode file (`.org`) that serves as a
living reference for every Mermaid diagram type. The document is explicitly
NOT a tutorial. It is a calibration artifact: a known-good example of each
type that an engineer can run against their local `mmdc` install to determine
exactly what works, what partially works, and what silently fails.

## Target Environment (be honest about this)

Primary: Emacs 29+, ob-mermaid, mmdc from npm, macOS arm64
Secondary: FreeBSD 14/15 on nexus (amd64), mmdc via npm under pkg node or
           ports, known to have version skew issues
Tertiary: GitHub .org rendering (does NOT execute Mermaid; diagrams appear
          as fenced code blocks — document this explicitly)
Validator: GitHub .md rendering (DOES execute Mermaid; use as ground truth
           for "is my syntax correct vs is my toolchain broken")

The document must distinguish between three failure classes:
1. SYNTAX ERROR — bad Mermaid spec (fix the prompt)
2. VERSION GAP — valid spec but requires mmdc >= X.Y (fix the toolchain)  
3. RENDERER GAP — works in mmdc but not in GitHub org / VS Code / etc.
   (fix expectations)

## Diagram Types to Cover

Cover ALL of the following, with one canonical minimal example each.
For each type include: the diagram source block, the known minimum mmdc
version, known renderer gaps, and a one-line description of the
primary use case in a software/systems engineering context.

### Stable Types (mmdc < 10.x)
- flowchart (TD, LR, BT, RL directions)
- sequenceDiagram
- classDiagram
- stateDiagram-v2 (NOT stateDiagram — v1 is deprecated)
- erDiagram
- gantt
- pie
- gitGraph

### Beta / Newer Types (mmdc >= 10.x)
- mindmap
- timeline
- xychart-beta (line, bar, combined)
- quadrantChart
- sankey-beta
- block-beta
- packet-beta
- architecture-beta

### Frequently Broken on FreeBSD / Older npm
- C4Context (requires @mermaid-js/mermaid-zenuml or plantuml bridge)
- zenuml (separate plugin, almost never installed)
- requirementDiagram (rarely rendered correctly)

## org-mode Babel Block Format

Every example MUST use this exact header format — do not deviate:

#+BEGIN_SRC mermaid :file ./diagrams/TYPE-NAME.png :exports both
...diagram source...
#+END_SRC

Additionally provide a companion tangle block that writes the raw .mmd file:

#+BEGIN_SRC mermaid :tangle ./diagrams/TYPE-NAME.mmd :mkdirp t
...same diagram source...
#+END_SRC

Rationale: the :file block exercises ob-mermaid's mmdc pipe; the :tangle
block produces a standalone .mmd that can be fed directly to mmdc for
debugging when ob-mermaid itself is the failure point.

## Required Document Structure

The output org file must have:

1. A file-level PROPERTY block with:
   - mmdc version used to validate examples
   - Date validated
   - Platform validated on
   - Known failures with explanation

2. A compatibility matrix as an org TABLE (not a Mermaid diagram — irony
   intentional) with columns:
   Type | Min mmdc | GitHub .md | GitHub .org | ob-mermaid | Notes

3. One top-level heading per diagram type with:
   - Description (one sentence)
   - Minimum mmdc version required
   - Known platform-specific failures
   - The canonical minimal example (the ob-mermaid :file block)
   - The tangle companion block
   - A "this is what broken looks like" note — what error or silent failure
     to expect when the version or renderer doesn't support it

4. A final section: "Debugging Runbook" — a decision tree for diagnosing
   why a specific Mermaid block failed in ob-mermaid, written as a
   stateDiagram-v2 (eat your own dog food).

## Specific Content Requirements Per Diagram Type

### flowchart
- Show all four direction variants (TD, LR, BT, RL) as separate blocks
- Include: node shapes (rectangle, round, diamond, stadium, subroutine,
  cylinder, circle, asymmetric, rhombus, hexagon, parallelogram, trapezoid)
- Include: edge types (arrow, open, dotted, thick, invisible)
- Include: subgraphs with direction override
- Note: `graph` keyword is deprecated alias for `flowchart` — show both
  and explain which to use

### sequenceDiagram
- Show: participants, actors, activation bars, notes, loops, alt/else/opt,
  par, critical, break, autonumber
- Include a realistic example: a P1 incident escalation sequence
  (relevant to the sprint planning context of the document this supports)

### stateDiagram-v2
- Show: simple states, transitions, composite states, concurrency (--),
  notes, choice pseudostate, fork/join
- Include a realistic example: a Jira issue lifecycle state machine
  (again: relevant to the document context)
- EXPLICITLY call out that stateDiagram (v1) is broken in most current
  renderers and should not be used

### classDiagram
- Show: class definition, attributes with visibility (+/-/#/~),
  methods, relationships (inheritance, composition, aggregation,
  association, dependency, realization), cardinality, namespaces
- Note the namespace support is mmdc >= 10.2 and broken on GitHub
  as of the validation date

### erDiagram
- Show: entities, attributes (type + name + key markers), relationships
  with cardinality (||--o{, etc.)
- Include a realistic example: a sprint/story/epic/team data model

### gantt
- Show: sections, tasks, done/active/crit modifiers, dateFormat,
  axisFormat, milestones, excludes
- Note: gantt is the most frequently broken diagram in ob-mermaid due to
  locale/date parsing issues on non-US systems — document the workaround
  (use ISO dateFormat YYYY-MM-DD explicitly)

### mindmap
- Show: root, levels, icons, classes, shapes (default, square, circle,
  bang, cloud, hexagon)
- Note: requires mmdc >= 9.4; shape support requires >= 10.0

### xychart-beta
- Show: line series, bar series, combined line+bar
- Show: both string-array x-axis (categorical) and numeric x-axis forms
  and explain the rendering difference
- Note: no legend labels yet; series are distinguished by color only;
  document the color order
- Note: y-axis range uses `-->` (double arrow) not `->` — common mistake

### quadrantChart
- Show: axis labels, quadrant labels, points with coordinates [0-1, 0-1]
- Note: point label overlap is not handled — document manual workaround

### timeline
- Show: title, sections (Era/Period labels), events under sections
- Note: requires mmdc >= 10.x; completely absent in older installs with
  no useful error message — just silent blank output

### gitGraph
- Show: commit, branch, checkout, merge, cherry-pick, tags, order
- Note: gitGraph direction (LR vs TB) requires mmdc >= 10.6
- Include a realistic example: a trunk-based development workflow with
  feature flags (relevant to §10.1 of the document this supports)

### sankey-beta
- Show: CSV-style node/link data format (it is NOT the same as other
  diagram types — document the format explicitly)
- Note: this is the most surprising syntax break — engineers expect
  graph notation and get CSV

### C4Context
- Note this requires the @mermaid-js/mermaid-zenuml package or plantuml
  and is almost never available in a standard mmdc install
- Show what the error looks like and the npm install command to fix it
- Suggest PlantUML via plantuml-mode as the more reliable alternative
  for C4 on the described platforms

## Tone and Style Requirements

- Assume the reader is a Staff+ engineer with formal methods background
  who will be annoyed by imprecision
- Do not hedge about whether things work — state what the minimum version
  is and what breaks below it
- Comments in org-mode babel blocks (# comment syntax) should be used
  liberally to explain non-obvious syntax choices
- Where Mermaid's syntax is genuinely surprising or counterintuitive,
  say so directly
- The FreeBSD situation should be addressed honestly: npm packages that
  depend on native binaries (canvas, puppeteer) are often broken; the
  recommended workaround is mmdc with --outputFormat=svg rather than PNG,
  which avoids the puppeteer/canvas dependency chain

## The One Thing You Must Not Do

Do not produce a document that only works in one renderer and pretends to
be a general reference. Every claim about rendering support must be
qualified by renderer and version. The whole point of this document is
to make the rendering gap legible, not to paper over it.

## Output Format

A single file: `mermaid-org-mode-reference.org`

The diagrams directory (`./diagrams/`) is created by :mkdirp t in the
tangle blocks. Do not create it manually or reference it before the
first tangle execution.

Validate your own output by mentally running through the compatibility
matrix before finalizing — if a diagram type you've included has a known
failure on FreeBSD/ob-mermaid, the failure must be documented in the
compatibility matrix AND in that type's section. No silent omissions.