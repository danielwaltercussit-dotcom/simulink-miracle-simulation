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
- any root-level line that remains `Connected='off'` after the automatic
  dangling-line cleanup
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

## Automatic Dangling-Line Cleanup

Run `cleanup_dangling_lines` before the final S3 audit. The helper must use the
Simulink line `Connected` property and must not classify a line as dangling
only because `SrcPortHandle` or `DstPortHandle` contains `-1`; SPS physical
connections can legitimately expose those handle values.

The default cleanup scope is the model root. Recursive cleanup requires an
explicit request because copied donor subsystems and linked blocks can contain
intentional internal drawing or implementation details.
