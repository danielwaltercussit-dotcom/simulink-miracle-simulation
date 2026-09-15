---
name: knowledge-graph-creation
description: Build and maintain the project-local power-system diagnostic knowledge base from reviewed papers and modeling experience, including source-linked relationships, alias resolution, applicability filters, contradictions, and incremental updates.
license: MIT
metadata:
  upstream: h4vzz/awesome-ai-agent-skills
  upstream_commit: 1615e6bb5fc09492de89fa864cf3d1dc88a5db9e
---

# Knowledge Graph Creation

Project adaptation of the upstream skill; see LICENSE. Use this for knowledge
maintenance, not as a mandatory step during each modeling run. The portable
store is the existing Markdown references, with stable IDs and relationship
tables. No database, embedding service, generated diagram, or API key is required.

## Maintain One Evidence-Linked Knowledge Layer

1. Read the relevant entry in
   [problem-solving knowledge base](../simulink-modeling-assistant/references/problem-solving-knowledge-base.md).
   For converter faults read
   [converter fault analysis](../simulink-modeling-assistant/references/converter-fault-analysis.md).
2. Extract only entities that change a diagnostic decision: symptom, device,
   controller, mechanism, mathematical object, analysis method, evidence, gate.
3. Normalize aliases without collapsing different physics: VSG/VSM are related
   control-family names; GFM includes other controls; DFIG is not a two-level VSC;
   IEEE39/case39 names do not establish matching dynamics or dispatch.
4. Use directed relations: symptom -> MAY_INDICATE -> mechanism;
   mechanism -> TEST_WITH -> method; method -> REQUIRES -> prerequisite;
   claim -> SUPPORTED_BY / CONTRADICTED_BY -> source; result -> LIMITED_TO -> scope.
5. Each relation retains a source ID and section/page, inference flag,
   applicability, and local reproduction state. Co-occurrence is not causation.
6. Merge new evidence into an existing entry. Preserve conflicting findings and
   invalidate stale dependent recommendations when an assumption changes.
7. Validate that IDs and relative links resolve, claims have sources, and no
   candidate is represented as a model-verified result.

## Retrieval

Filter first by topology, control, fidelity, operating point, limiter state,
and evidence level. Then match symptoms and rank analysis paths. Return the
selected KB/source IDs, first discriminating measurement, stop condition, and
at most three useful source pointers. Unknown applicability stays unknown.
This is an agent reading procedure, not a claim that the existing ML dataset
builder implements graph filtering.

## Admission

Use [research-paper-review](../research-paper-review/SKILL.md) for new papers.
A reviewed theoretical diagnostic can be available for consultation while
its model application remains untested. Only model-backed verification can
promote a concrete tuning action or model PASS. Put run evidence in existing
report locations; keep binaries, full papers, and generated indexes out of
the portable knowledge layer.

## Provenance

Installed from upstream commit above on 2026-09-14, then adapted for local
Markdown storage, scientific evidence levels, and bounded modeling workflows.
Upstream generic examples and mandatory graph exports were removed.
