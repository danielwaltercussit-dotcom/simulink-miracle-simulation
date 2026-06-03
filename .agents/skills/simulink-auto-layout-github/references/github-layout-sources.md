# GitHub Layout Sources

## Installed Sources

| Source | Local path | Use |
|---|---|---|
| McSCert/Auto-Layout | `external/github/McSCert-Auto-Layout` | Simulink automatic layout with Graphviz, GraphPlot, and DepthBased approaches. |
| McSCert/Simulink-Utility | `external/github/McSCert-Simulink-Utility` | Bounds, line routing, Goto/From discovery, connected-block utilities. |
| simulink/skills | `external/github/simulink-skills-upstream` | Upstream Simulink agent skills, including context resolution and positioning conventions. |

## Selection Notes

- McSCert Auto-Layout is best for ordinary signal-flow subsystems and model formatting experiments.
- For power-system topology review diagrams, deterministic one-line coordinates remain safer than graph layout.
- Simulink-Utility is useful for analysis helpers such as line bounds, block bounds, Goto/From discovery, and connected-block traversal.
- The upstream `simulink-interactions` skill favors resolving paths from live model context and using positioning helpers instead of raw path guesses.

## Current Project Policy

- Physical SPS/Simscape electrical lines stay explicit.
- Long measurement/control wires can become `Goto`/`From` pairs.
- Run layout tools on derived models, not on imported benchmark references.
- Always export a visual preview after layout changes.
