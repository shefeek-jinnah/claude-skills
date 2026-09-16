# name-terminal-tab

Names your macOS Terminal tab after the project folder and the task Claude Code
is working on, and updates it as work progresses:

    myrepo                                     session start
    ● myrepo — fix the auth redirect loop      working
    🔔 myrepo — fix the auth redirect loop     waiting on your approval
    ✓ myrepo — fix the auth redirect loop      done

You can also pin a name by just asking Claude — *"name this tab release
checklist"* — and go back to automatic with *"go back to automatic naming"*.

## What's in here

| Path | What it is |
| --- | --- |
| `SKILL.md` | The skill: teaches Claude to pin/clear a tab name on request. Installs to `~/.claude/skills/name-terminal-tab/`. |
| `hook/claude-terminal-title.pl` | The hook that does the automatic naming. Installs to `~/.claude/hooks/`. |
| `hook/claude-name-tab` | Manual rename helper. Installs to `~/.local/bin/`. |
| `hook/install.sh` | Installs all three and wires the hook into `~/.claude/settings.json`. |

## Install

    ./name-terminal-tab/hook/install.sh

`install.sh` resolves everything relative to its own location, so it works from
any directory. It installs the skill (`SKILL.md`, one level up from `hook/`) as
well as the hook and the helper — no separate copy step.

Then start a new Claude Code session; hooks and skills both load at session
start.

It is safe to re-run: existing entries for this hook are replaced rather than
duplicated, any other hooks you have are left alone, and your previous
`settings.json` is backed up alongside itself first.

## Manually rename a tab

    ~/.local/bin/claude-name-tab "API refactor"   # pin a name
    ~/.local/bin/claude-name-tab --clear          # back to automatic
    ~/.local/bin/claude-name-tab --show           # what's pinned right now

A pinned name is keyed by the tab's tty, so each tab is independent and the name
survives `/clear` and a new session in the same tab.

## Try it

- Just prompt normally — the tab title updates on its own.
- Say *"name this tab release checklist"* → pins it.
- Say *"go back to automatic naming"* → unpins it.

## Uninstall

    ./name-terminal-tab/hook/install.sh --uninstall

Removes the hook, the helper and the installed skill, and strips the hook
wiring back out of `settings.json`.

## Requirements

macOS with Terminal.app or iTerm2, and the perl that ships with macOS. No other
dependencies. The title escape (OSC 0) also works in Ghostty, WezTerm and Kitty.
In the VS Code integrated terminal the editor may override the title depending
on `terminal.integrated.tabs.title`.
