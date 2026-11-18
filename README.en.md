# claude-terminal

[Magyar](README.md) | **English**

Windows Terminal setup for Claude Code: project picker, launcher profiles, pane shortcuts and
command palette submenus, with a single installer.

> **Unofficial project.** It is not made by, affiliated with, or endorsed by Anthropic.
> "Claude" and "Claude Code" are trademarks of Anthropic.

> **Note on language:** the user interface (menus, prompts, palette entries) and the installer
> parameters are in Hungarian. Everything works the same for non-Hungarian speakers; this README
> explains what each item means.

## Why is it handy?

If you work on several projects with Claude Code, your day starts with opening a window, `cd`-ing
into the right folder and starting `claude`. To pick up unfinished work you also have to remember
which folder it was in and which flag to use. This package shortens all of that to a single key or
a pick from a list:

- **Desktop icon that picks up where you left off.** The "Claude projektek" (Claude projects) icon
  asks: new work (project picker), or continue the previous session. When continuing, every
  project of the previous session opens in its own tab, and in each one Claude continues the last
  conversation.
- **One key and you are in the project.** `Ctrl+Shift+3` opens the project list. Type a number
  and Claude is already running in that folder. Recently used folders are added automatically.
- **Resume in one step.** `c2` continues the last session of project 2, `r2` lets you choose from
  earlier ones. No need to remember where you were.
- **Several projects side by side.** `Alt+Shift+V` / `H` opens a new pane (the tab split in two)
  with the same picker. A pane can be zoomed, moved to a new tab or window, and moved back.
- **Screenshot with one key.** `Alt+S`, pick a monitor (or an area), and the image is already in
  Claude's input line; you only have to type the question.
- **Help at the bottom of the picker.** The picker's commands and the Terminal keys
  (screenshot, panes) are visible at a glance, so you don't have to memorize them.
- **Everything works from the command palette too.** `Ctrl+Shift+P`, type "claude", then type the
  project name to start, resume or manage the list.
- **A tidy Terminal.** New launches open as a new tab in the existing window, Claude tabs are
  colored, and their icons show which is which.
- **Simple installation.** One double-click, works offline. It does not touch your existing
  Terminal settings, and it makes a backup first.

## What it looks like

- **Project picker** (`Ctrl+Shift+3`): pinned projects at the top, recently used ones below with
  dates. Folders with the same name are distinguished by their parent folder.
- **Several sessions in one window:** multiple panes in one tab, each running Claude in a
  different project, independently. New pane: `Alt+Shift+V` (right) / `H` (down), and the same
  picker comes up inside it. Switch: `Alt+arrows`, resize: `Alt+Shift+arrows`, close:
  `Ctrl+Shift+W`.
- **Pane management:** zoom (`Alt+Shift+Z`), move to a new tab (`Alt+Shift+T`) or a new window
  (`Alt+Shift+N`), back to an existing tab with `Alt+Shift+1…9`. The running session is not
  interrupted.
- **Command palette** (`Ctrl+Shift+P`, "claude"): start in a new tab or pane, continue, earlier
  session, list management (rename, pin, delete, new folder).
- **New tab menu** (the dropdown next to `+`): the three Claude profiles at the top.

## Installation

Requirements: Windows Terminal (started at least once), PowerShell 7 (`pwsh`) and the `claude`
command. If one is missing, the installer tells you how to get it.

**Easiest if you already use Claude Code:** tell it:

```
Install this for me: https://github.com/kismaszek/claude-terminal
```

Claude downloads it, asks for the two working folders and runs the installer.

> **Installation guide for Claude:**
> 1. Clone the repo into `$env:USERPROFILE\claude-terminal`. If a clone is already there, run
>    `git pull` instead.
> 2. Ask the user for the working folder of the "Céges" (work) and the "Magán" (personal)
>    profile. Suggestion: work = `D:\CLAUDE` if it exists, otherwise the user folder; personal =
>    `~\claude-workspace` if it exists. `-` means that profile should not be created.
> 3. Run: `pwsh -NoProfile -File $env:USERPROFILE\claude-terminal\install.ps1 -Ceges <folder>
>    -Magan <folder|->`. If the user later wants to be asked again, use `-Ujrakonfig`.
> 4. If the installer reports a missing requirement, tell the user what is missing and how to
>    get it, then run it again.
> 5. At the end, report the installer output, and that `Ctrl+Shift+3` or the "Claude projektek"
>    desktop icon starts it. Do not start Windows Terminal from a tool call, because
>    `CLAUDE_CODE_CHILD_SESSION` would be inherited and Claude started there would not write a
>    transcript.

**With a git clone** (recommended, updating is then a `git pull`):

```powershell
git clone https://github.com/kismaszek/claude-terminal.git $env:USERPROFILE\claude-terminal
pwsh -File $env:USERPROFILE\claude-terminal\install.ps1
```

This installs in place; the profiles point to the clone. Changes to the menu script take effect
right after `git pull`; after a change to `wt-claude.json`, run `install.ps1` again.

**Update notice:** when a Claude profile starts, the script runs `git fetch` in the background
(waiting at most 3 seconds, so an unreachable server does not block it). If the remote branch is
ahead, the picker lists the new commits, and `u` runs `git pull` and `install.ps1`, then restarts.
The work/personal profiles only print one line and do not wait for the fetch (they show the result
of the previous start).

**Offline, from a package:** on GitHub *Code → Download ZIP*, or copy the folder via USB stick or a
network share. After extracting, double-click `telepites.cmd`. The files are copied to
`%LOCALAPPDATA%\claude-terminal`, and the download can be deleted afterwards. Update: a new package,
and `telepites.cmd` again.

**On first install** the installer asks for the machine's two working folders, for the "Céges"
(work) and the "Magán" (personal) profile (Enter = the suggestion, `-` = no such profile). The
answers are stored in `gep.json`; to be asked again: `-Ujrakonfig`.

**Desktop icon:** the installer creates the "Claude projektek" shortcut on the desktop (skip it
with `-NincsIkon`). When started, it shows:

```
  Claude – indítás

   1) Új munka: projektválasztó
   2) Előző munkamenet folytatása (bezárva 2026-11-11 12:42, 3 projekt):
        1. Website  D:\Projects\website
        2. SmartHome  D:\Projects\smarthome
        3. Notes  D:\Projects\notes

  Választás (Enter = 1)
```

(1 = new work: project picker; 2 = continue the previous session, closed at the given time, with
3 projects.) After `2` it asks which ones to continue (Enter = all, or numbers such as `1,3`). The
first project starts in the current tab, the others in new tabs of the same window, each with
`claude --continue`. If there is no previous session (first use), the project picker comes up
directly.

**What the previous session is:** every Claude tab (menu, palette, work/personal profile, restore)
keeps a marker file in the `munkamenetek\` folder while running (per machine, not versioned) and
refreshes it every 20 seconds. When Claude exits normally, the marker is deleted. If the tab or
window is closed or the machine shuts down, the marker stays, and its last refresh shows when the
tab ended. The tab also flags its marker at the moment it is closed, because Windows keeps the
closed process alive for a few seconds; so a window started right after closing also offers the
restore. The previous session is the set of tabs that ended last, together (within 90 seconds).
Tabs closed earlier, separately, and tabs still running are not included. After a restore the old
markers are deleted. Choosing "new work" keeps them, so the restore stays available later.

The installer merges the settings from `wt-claude.json` into the Terminal's `settings.json`,
making a backup first (`settings.json.bak-<timestamp>`). It can be run repeatedly. Profiles are
replaced by guid, actions by id, and for key bindings any other binding on the same key is
removed. `-WhatIf`: only prints what it would do.

## Keys and commands

| Key / place | What it does |
|---|---|
| `Ctrl+Shift+1` | "Céges" (work) Claude in a new tab (in the machine's work folder) |
| `Ctrl+Shift+2` | "Magán" (personal) Claude in a new tab (in the machine's personal folder) |
| `Ctrl+Shift+3` | "Claude – projekt": the picker menu |
| `Alt+Shift+V` / `H` / `D` | new pane right / down / automatic, with the picker menu |
| `Alt+Shift+Z` | zoom pane / restore |
| `Alt+Shift+T` / `N` | move pane to a new tab / new window |
| `Alt+Shift+1…9` | move pane to tab 1–9 |
| `Alt+S` | screenshot for Claude: choose monitor / all / area / last image (see below) |
| `Ctrl+Shift+P` → "claude" | Claude: project in new tab / new pane / continue / earlier session, manage project list |
| `Alt+Shift+-` / `Alt+Shift+=` | duplicate the current pane down / right (Terminal default, unchanged) |

Below the project list, the picker also shows its own commands and the Terminal keys above
("Billentyűk": screenshot, panes), so you don't have to memorize them.

**Picker commands:**

| Input | What it does |
|---|---|
| `3` | start Claude in project 3 (Enter = the 1st) |
| a path | start Claude in that folder |
| `c3` / `r3` | continue the last session of project 3 / choose an earlier session |
| `+` / `+C:\folder` | pin a new folder (asks for a name) |
| `+3` | pin item 3 (e.g. a recently used one) |
| `a3` | rename item 3 |
| `-3` | delete item 3 (for a recently used one: hide it) |
| `m5 1` | move item 5 to position 1 (`m5` = asks for the position) |
| `f3` | give item 3 a fixed position (it always stays 3rd); `f3` again = remove the fixed position |
| `k <name>` | search for a folder by name (case and accents are ignored) |
| `k` | discover new project folders: ones with `.git`, `CLAUDE.md` or `.claude` that are not yet on the list |
| `u` | update, when the picker reports new commits in the repo |
| `q` | quit, leaving a PowerShell prompt |

**Screenshot (`Alt+S`):** a small picker opens below the Claude pane. `1`…`9` = that monitor (left
to right; the Terminal's monitor is marked), `a` = all monitors together, `t` = select an area
(Win+Shift+S), `u` = the most recent screenshot (from the Win+Shift+S / PrtScn save folder or from
`Pictures\Claude`), `Esc` = cancel. After choosing, the picker closes, the image goes to the
clipboard, and a hidden helper process sends `Alt+V` to the Terminal, which makes Claude Code paste
it (`[Image #1]`). If the Terminal is on the chosen monitor, it is minimized for the capture so it
does not cover the content. Monitor captures are also saved to `Pictures\Claude`. On error, details
are in the repo's `kepernyokep.log`; if the paste does not happen (e.g. you clicked elsewhere
meanwhile), the image is on the clipboard and can be pasted manually with `Alt+V`.

Global setting (`wt-claude.json` → `globals`): `windowingBehavior: useAnyExisting`, so a new
Terminal launch (shortcut, `wt`, Start menu) opens as a new tab in the existing window.

`defaultProfile`: the "Claude – projekt" profile, so the tab bar's **+** button (and
`Ctrl+Shift+T`, and a plain `wt` / Start menu launch) opens the project picker. For a plain
PowerShell, choose it from the dropdown next to +.

Before every Claude launch, the `CLAUDE_CODE_CHILD_SESSION` and `NO_COLOR` variables are cleared.
If a Terminal window was started by a Claude session's tool call, these are inherited, and then the
session writes no transcript (`--resume` cannot see it) and runs in black and white.

## Project list

- **Per machine:** `claude-projektek.txt` is the machine's own list and is not committed. If it
  does not exist yet, it is created from `claude-projektek.minta.txt`. Format: `Name | Path`,
  `#` = comment, `! path` = hidden folder, `[3] Name | Path` = item with a fixed position.
  Paths that don't exist are skipped.
- **Order:** fixed items always stay at their own position. The other items fill the remaining
  slots: first the pinned ones in file order, then the recently used ones by time of use. If a
  fixed position is larger than the list, the item goes to the end.
- **Moving (`m<number> <position>`):** for a fixed item it changes the fixed position, and if
  another fixed item is at the target, the two swap. For a pinned item it changes the order of the
  pinned items; it cannot take a fixed item's place. A recently used item is pinned first. An item
  cannot be moved among the recently used ones; it goes to the end of the pinned ones instead.
- **Fixed position (`f<number>`):** the item stays where it is now. A recently used item is also
  pinned for this. After removing the fixed position, the item stays pinned.
- **Recently used folders:** from `~/.claude/projects`, newest first, at most 15.
- **Renaming:** renaming a recently used item moves the folder to the pinned items with the new
  name, because names can only be stored there.
- **Deleting:** for a pinned item it removes the line. For a recently used item it writes a
  `! <path>` line, so the folder no longer appears. To bring it back: `+<path>`.
- **Search (`k`):** searches fixed drives and the user folder, at most 4 levels deep, for up to 15
  seconds. System folders (`Windows`, `Program Files`, `AppData`…) and build/dependency folders
  (`node_modules`, `bin`, `obj`…) are skipped. Among the results, a number = start Claude there,
  `+<number>` = pin to the list. In the command palette: manage project list → search project
  folder.

The picker refreshes the palette submenus on every start (only if something changed). Manually:

```powershell
pwsh $env:USERPROFILE\claude-terminal\claude-projekt.ps1 -CsakPaletta
```

## Versioning

The version number is in the `VERSION` file (SemVer: major.minor.patch), changes are in
`CHANGELOG.md` (in Hungarian). The installer and the menu header show the current version, and the
update notice shows both the old and the new one (e.g. `v1.0.0 → v1.1.0`).

**Release:** bump `VERSION`, add a new section at the top of `CHANGELOG.md`, commit to `main`, then
an annotated tag and push:

```powershell
git tag -a v1.2.1 -m "1.2.1"
git push origin main --follow-tags
```

Smaller commits (e.g. README fixes) can go without a version bump. The update notice then only
shows the number of commits.

## Customization

- Working folders: `install.ps1 -Ujrakonfig`, or `install.ps1 -Ceges <folder> -Magan <folder|->`.
- Profiles, actions, keys, global settings: in `wt-claude.json`, then `install.ps1`. Not directly
  in the Terminal's `settings.json`, because the next install overwrites it.

## License

MIT, see the [LICENSE](LICENSE) file: free to use, modify and redistribute, keeping the copyright
notice, without warranty.
