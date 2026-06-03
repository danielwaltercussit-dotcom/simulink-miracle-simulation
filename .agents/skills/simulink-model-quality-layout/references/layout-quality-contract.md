# Layout Quality Contract

## Reference Sources

Use the desktop archive as read-only layout guidance:

- `M01-02_4M2A_DFIG`: symmetric two-area physical layout; keep major machine
  groups in clear columns or rows with generous spacing.
- `M07_SGbyhjq_NEBUS39`: clean single-machine template; good donor for compact
  source-transformer-line-load arrangements.
- `M08_VSCbyhjq`: legal Goto/From reference; tags are for ordinary
  measurement/control signals such as `Utabc`, `Itabc`, `Inetabc`, `Unetabc`.

Do not edit files in `C:\Users\jonas\Desktop\实验室仿真模型汇总`; use them as
oracles when deriving layout conventions.

## Hard Failures

- any root canvas overlap
- Goto/From tags that appear to carry physical phase terminals or SPS
  connection names
- no measurement/logging surface (`To Workspace` or root `Outport`)
- missing project oracle files

## Warnings

- high root block count with low subsystem encapsulation ratio
- missing desktop lab reference archive
- layout extents that are much wider or taller than the project pattern

Warnings should be reported first and tightened only after a model family has a
validated reference envelope.
