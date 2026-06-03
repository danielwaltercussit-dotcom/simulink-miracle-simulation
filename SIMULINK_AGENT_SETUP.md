# Project-Local Simulink Agent Setup

This folder contains a project-local installation of both Simulink skill
repositories:

- Official toolkit: `external/simulink-agentic-toolkit`
- Supplemental skills: `external/simulink-skills`

The project-local skill registry is `.agents/skills`. It contains junctions to
the skill folders inside `external/`, so pulling updates in the cloned
repositories updates the registered skills automatically.

## Installed Skills

Official Simulink Agentic Toolkit core skills:

- `building-simulink-models`
- `filing-bug-reports`
- `generate-requirement-drafts`
- `simulating-simulink-models`
- `specifying-mbd-algorithms`
- `specifying-plant-models`
- `testing-simulink-models`

Supplemental Guy on Simulink skills:

- `simulink-debug-commandline`
- `simulink-interactions`
- `simulink-profile-initialization`
- `simulink-profiler-analyzer`
- `simulink-solver-profiler-analyzer`

## MATLAB Initialization

Open MATLAB, switch to this folder, then run:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
```

This adds the project-local Simulink Agentic Toolkit to the MATLAB path and runs
`satk_initialize`.

## Trigger Examples

Use explicit skill names when you want predictable behavior:

```text
Use the building-simulink-models skill to inspect and extend power_KundurTwoAreaSystem.slx.
```

```text
Use the simulating-simulink-models skill to run a parameter sweep for this model.
```

```text
Use the simulink-interactions skill to find all Gain blocks in this subsystem.
```

## Updating

From this project folder:

```powershell
git -C external\simulink-agentic-toolkit pull
git -C external\simulink-skills pull
```

No global skill directories are required for this project-local setup.
