---
name: name-terminal-tab
description: Rename the macOS Terminal window/tab for the current Claude Code session. Use when the user asks to name, rename, label, title or pin this tab, terminal, window or session, or to go back to automatic naming.
---

# Name the terminal tab

The `claude-terminal-title` hook names each Terminal tab `<folder> — <task>`
automatically, deriving the task from the user's most recent prompt. This skill
is the manual override: it pins a name that sticks for the rest of the session
in that tab, until cleared.

## Pin a name

Run, via Bash, in the session's own working directory:

```bash
~/.local/bin/claude-name-tab "API refactor"
```

The helper prints the resulting title. Report it back in one short line — e.g.
"Tab is now `myrepo — API refactor`." Do not explain the mechanism unless asked.

## Go back to automatic naming

```bash
~/.local/bin/claude-name-tab --clear
```

## Check what is pinned

```bash
~/.local/bin/claude-name-tab --show
```

## Choosing the name

- If the user gave an explicit name, use it verbatim — do not tidy or expand it.
- If the user asked to rename the tab without saying what to, derive a 2–4 word
  label from what is actually being worked on in this session ("auth redirect
  fix", "Q3 report"). Keep it under about 30 characters; the folder name is
  already prefixed, so do not repeat it in the label.
- Never include secrets, tokens, customer names or file paths in the title — it
  is visible in window lists, screen shares and screenshots.

## If the helper is missing

`command -v claude-name-tab` failing (or no such file) means the hook package is
not installed on this machine. Set the title for this one tab directly:

```bash
printf '\033]0;%s\007' "$(basename "$PWD") — API refactor" > /dev/tty
```

That write is not persistent: the next hook event, or the next command that sets
a title, will overwrite it. Say so, and mention that installing the
`claude-terminal-title` hook package makes both the automatic naming and the
pinning stick.

## Notes

- State is keyed by the controlling tty, so each Terminal tab is independent and
  a pinned name survives `/clear` and a new session in the same tab.
- Writing to `/dev/tty` is what reaches the terminal; plain stdout from the Bash
  tool is captured by Claude Code and will not change the title.
- This is macOS Terminal.app and iTerm2 (OSC 0). It also works in Ghostty,
  WezTerm and Kitty. In the VS Code integrated terminal, the editor may override
  the title depending on `terminal.integrated.tabs.title`.
