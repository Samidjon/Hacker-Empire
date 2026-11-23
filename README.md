# Hacker Empire

Isometric cyberpunk hacker tycoon RPG, built with Godot 4 and GDScript.
All hacking in the game is fictional and self-contained; nothing touches real systems.

**Current milestone: MVP 8 - Expansion and Story (complete).** See
[documentation/MVP_PROGRESS.md](documentation/MVP_PROGRESS.md).

## Requirements

- Godot **4.7** (developed and validated on 4.7.2 stable). The standard or the .NET build both work;
  the project uses GDScript only.
- Windows 10/11.

## Running the game

1. Open Godot, choose **Import**, and select `project.godot` in this folder.
   The first import builds the `.godot/` cache (required before running from the command line).
2. Press **F5**.

Or from PowerShell:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64_console.exe" --path .
```

## Controls

| Key | Action |
|---|---|
| W A S D / arrow keys | Walk |
| E | Interact with the highlighted object |
| Esc | Pause menu (or log off when at the computer) |

## What you can do so far

- Main menu: **Continue**, **New Game**, **Load Game**, **Quit**.
- New game: pick one of 3 save slots (overwrite needs confirmation), choose a hacker alias.
- Walk around the isometric apartment. Walls and furniture block you; the camera follows.
- Interact: **computer** (opens the workstation), **bed** (rest and save), **storage** and
  **window** (inspect).
- Use the computer's desktop (**EMPIRE//OS**): launcher, draggable windows with minimise /
  maximise / close, taskbar switching, unread-mail badge. Windows stay open when you get up.
- Applications that work now:
  - **Dashboard**: profile, XP, balance, reputation, heat, playtime, recent transactions.
  - **Terminal**: fictional commands (`help`, `status`, `ls`, `cd`, `cat`, `open <app>`, ...).
  - **File Manager**: browse and read the in-game file system.
  - **Mail**: inbox with messages that arrive as you progress.
  - **Finance**: income and expenses by category, full transaction history.
  - **Network Map**: the fictional grid; nodes are discovered as you level up.
  - **Contracts**: a board of paid jobs. Accept one and play its stages.
- **Contracts** are how you earn money, XP and reputation:
  - 14 contracts in 7 categories (file recovery, security audit, malware investigation, network
    analysis, software debugging, cryptography, incident investigation); more unlock as you level.
  - Each contract has 2-4 stages, each a puzzle: put entries in order, find the letter shift,
    spot the problem lines, or find the identical code.
  - Three mistakes or running out of time fails the contract and costs reputation.
    A run with no mistakes pays a 10% bonus.
  - Jobs from anonymous clients pay more, build underground reputation and raise heat.
  - A contract in progress is saved and resumes on the same puzzle.
- **Hardware** (Marketplace and Hardware apps): 38 parts in 8 slots (CPU, GPU, RAM, SSD, network
  adapter, cooling, monitors, servers), tiers 1-4. Buying a part installs it; the old one goes to
  the storage cabinet and can be swapped back. Parts add Speed (more time on contracts), Capacity
  (more offers on the board), Network (new offers sooner) and Research (used from MVP 7).
- **Skills** (Skills app): a tree of 18 skills in 6 branches. You get one skill point per level.
  Skills raise pay for a contract category, add time, allow an extra mistake, add board offers,
  cut heat from underground work, and more.
- Some higher contracts require a hardware tier or a skill level.
- **Company** (Organization app): from level 3 you can register a company for a fee. It has a
  name, a level, a reputation and an office. Offices come in six sizes; a bigger one costs money
  to move into and rent every business day, and has more desks.
- **Staff** (Employees app): candidates apply every business day. Six roles (programmer, security
  analyst, network engineer, reverse engineer, AI engineer, system administrator). Each person
  has skills, experience, a salary, productivity, energy and morale. Assign each one to client
  work (earns money daily), supporting you (gives you their role's bonus on contracts), training
  (levels up faster) or time off (restores energy and morale).
- **Business days**: every two minutes of play a day ends: staff earn, rent and salaries are
  paid, and a daily report is filed. Unpaid staff lose morale and eventually resign; unpaid rent
  becomes a debt that blocks hiring and expansion.
- **Research** (Research app): 10 projects. A project costs money to start and takes play time;
  a GPU, servers, AI skills and staff assigned to Research make it faster. A finished project
  gives a permanent bonus, some pay a grant, and some make a software product possible.
- **Products** (Products tab): a registered company can develop software. One-time products sell
  strongly at launch and fade; subscriptions build up subscribers and cost server maintenance.
- **Running costs**: with a company, upgraded hardware has a daily electricity bill.
- **World events**: now and then something happens (a rush client, a failing part, a resignation
  letter, a research breakthrough...) and you must choose. Each choice has real consequences.
  The game pauses while you decide.
- All 13 applications are now installed.
- **Story**: seven chapters take you from "Bedroom Operator" to "Hacker Empire". The current
  chapter and its objectives are shown on screen while you walk around; finishing a chapter pays
  a reward and a mail introduces the next. Finishing the last one shows an ending screen, after
  which you can keep playing.
- **The office**: once your company has moved out of the home office, the door in your apartment
  takes you there. The office grows with the office tier, has a desk for every place, and your
  staff sit at them. Walk up to someone and press E to hear how they are doing. The office has
  its own workstation with the same desktop.
- **Dev Tools** app (debug builds only): grant XP / money / reputation / heat for testing.
- Pause menu with Save, Save & Exit, Save & Quit.
- Autosave every 2 minutes and when the window is closed. Your position in the room is saved.

Saves are stored in `%APPDATA%\Godot\app_userdata\Hacker Empire\saves\`.

## Tests

```powershell
.\tests\run_tests.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
```

| Scene | What it checks |
|---|---|
| `tests/TestRunner.tscn` | Unit tests for every system (`tests/contract_tests.gd` for puzzles and contracts, `tests/upgrade_tests.gd` for hardware, skills and bonuses, `tests/company_tests.gd` for the company and staff, `tests/research_tests.gd` for research, products, running costs and events, `tests/story_tests.gd` for the story and travel between rooms) |
| `tests/FlowTest.tscn` | End-to-end run with real input: menu, walking, collisions, interactions, desktop windows, every app, buying and swapping hardware, learning a skill, founding a company, hiring, a business day, research, a product release, a world event, a story chapter, a trip to the office, the ending screen, a contract played to the end, failure, pause, save/load |
| `tests/ScreenshotTour.tscn` | Not headless. Opens each screen and saves PNGs to `user://screenshots` |

Tests use their own save directories and never touch real saves.

## Documentation

- [ARCHITECTURE.md](documentation/ARCHITECTURE.md) - systems, rules, how to add a new system
- [SCENE_REFERENCE.md](documentation/SCENE_REFERENCE.md) - every scene and its script
- [MVP_PROGRESS.md](documentation/MVP_PROGRESS.md) - milestone status
- [CHANGELOG.md](documentation/CHANGELOG.md)
