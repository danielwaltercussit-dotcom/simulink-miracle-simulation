# Same-Folder Conversation Takeover

Use one of the following prompts when another conversation takes over work in
this project.

## Codex Review Or Planning Conversation

```text
Continue the current Simulink modeling-test work from disk, not chat history.
First read:
1. AGENTS.md
2. docs/CODEX_CLAUDE_COLLABORATION.md
3. docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md
4. build/reports/agent_handoff/latest_claude_packet.md
Then follow the latest pointer to the named package and review evidence.

Preserve all in-flight changes. Treat oracle/reference models as read-only.
The model is at the closed-loop tuning entry gate, not at accepted tuning
convergence. Enforce the approved tuning priority and the immutable device
boundary. Start with git/status and disk evidence, report findings first, and
prepare the next compact READY package only after review.
```

## Fresh Claude Code Execution Conversation

The directly transferable text is always written to:

`build/reports/agent_handoff/next_claude_prompt.txt`

```text
Start one fresh bounded work chunk. Read only
build/reports/agent_handoff/next_claude_prompt.md, then only its named mandatory
evidence files. Do not read old chats, scan the repository, or read the package
packet/global pointer at startup.

Before editing, confirm package_id, workdir, objective, write scope, validation,
and stop condition in one line. Execute the ordered gates. For runs over 60
seconds use detached execution and validated mutually exclusive flags. Re-read
evidence, overwrite the named packet with a compact HANDBACK under 60 lines,
and stop without beginning the next chunk.
```
