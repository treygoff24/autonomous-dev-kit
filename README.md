# autonomous-dev-kit

A practical harness for long-running, autonomous AI development. I stole all the good parts of continuous claude v2, ralph riggum claude code plugin, and misc. other open source stuff the cursed X algorithnm gives me, threw in a few simple pieces of my own, and combined them all here. It is built around Claude Code and Codex and actually works for the use case everyone is promising of "chat with an AI Agent, let it work for hours, return to a completed working finished product". As far as I can tell, this harness is the only one capable of doing that so far (before anyone tries this and yells at me, do note I am not saying "bug free", I am just saying "it will actually work and be about 90% of what you intended, with zero work from you").

Most agent setups break down once the task lasts more than a few minutes. Context gets shredded by compaction, prompts drift, tests are skipped, and the model starts guessing. This kit exists because I got tired of cleaning up after that.

The core idea is boring on purpose: specs, plans, checkpoints, and hard quality gates. The hooks keep context hydrated, the skills keep the protocol tight, and the stop hook refuses to let a run declare victory without the proof. Claude Code 2.1+ features like skill-scoped hooks and hot reload are incorporated thoughtfully as well.

I also wanted a harness that treats model choice as a tool, not a religion. Claude does the building, Codex and Gemini do cross-review, and they keep each other honest.

Parallelism is handled carefully. The ticket-builder workflow pushes single tasks into isolated worktrees with explicit file ownership and a mandatory review gate. You get speed without stepping on rakes.

As far as me and GPT-5.2 can tell after a quick scan, this is the only open-source harness that combines all of that in one place: continuous context, protocol enforcement, skill/agent separation, hook-based autonomy, and multi-frontier-model review. If you find another one, send it to me so I can steal the good parts and add them here.

If you are trying to ship something real with AI agents and want fewer surprises, this is the harness that will actually work.

## Quick Start

### Prereqs

macOS or Linux, Git, and a Claude API key. Use the installation method of your choice to install Claude Code. Codex and Gemini are optional but recommended for cross-review.

### Install

Maximum autonomy warning: the install and example commands use `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex) to remove prompts. Use this only in trusted repos and remove those flags if you want approval gates.

```bash
git clone https://github.com/treygoff24/autonomous-dev-kit.git
cd autonomous-dev-kit
./install.sh
```

### First project

```bash
mkdir my-project && cd my-project
autonomous-init
```

Then open Claude Code and say: "Read the autonomous build protocol and help me write a spec for [your idea]."

## How it works

Hooks keep sessions stable through compaction and restarts. Templates and skills enforce a spec -> plan -> build loop with review checkpoints. The stop hook blocks exit if tests or plan tasks are incomplete, and it periodically forces a protocol refresh so the model does not drift and stays locked in. The shell helpers keep the whole thing ergonomic. I put quite alot of thought and trial and error into when to make something an agent vs. skill vs. protocol step. details below:

## Agents, skills, rules

### Agents (isolated, parallel execution)

| Agent                   | Purpose                                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `debugger`              | Systematic debugging with root-cause analysis so fixes stick instead of chasing symptoms.             |
| `tdd-implementer`       | Writes tests first and then implementation to reduce regressions and force clear acceptance criteria. |
| `plan-executor`         | Executes a plan task-by-task with quality gates so long runs stay aligned and verifiable.             |
| `code-reviewer`         | Reviews diffs against the spec and plan to catch gaps before commits.                                 |
| `a11y-reviewer`         | Checks UI work for accessibility issues so you do not ship obvious a11y regressions.                  |
| `spec-reviewer`         | Audits specs for missing details and ambiguity to prevent vague builds.                               |
| `review-triager`        | Sorts review feedback into fix-now vs later so changes stay focused.                                  |
| `ticket-builder`        | Implements a single plan task in an isolated worktree to enable safe parallel work.                   |
| `slop-cleaner`          | Removes boilerplate and AI cruft so the codebase stays readable.                                      |
| `validator`             | Cross-checks changes for edge cases, tests, and safety before moving on.                              |
| `root-cause-tracer`     | Traces failures backward through the stack to find the first wrong assumption.                        |
| `parallel-investigator` | Splits independent issues into parallel investigations to reduce time to diagnosis.                   |

### Skills (interactive workflows)

| Skill                             | Purpose                                                                       |
| --------------------------------- | ----------------------------------------------------------------------------- |
| `/brainstorming`                  | Turns fuzzy ideas into concrete options and decisions so specs start strong.  |
| `/writing-plans`                  | Creates phased implementation plans with clear tasks and acceptance criteria. |
| `/using-git-worktrees`            | Guides creation of isolated worktrees for risky or parallel changes.          |
| `/finishing-a-development-branch` | Runs a cleanup checklist so branches are merge-ready.                         |
| `/requesting-code-review`         | Packages the diff for a review agent and gets a structured verdict.           |
| `/receiving-code-review`          | Converts review feedback into a prioritized fix list and execution steps.     |
| `/spec-quality-checklist`         | Applies a spec completeness checklist to remove ambiguity.                    |
| `/accessibility-checklist`        | Applies an a11y checklist to catch common UI gaps.                            |
| `/autonomous-loop`                | Activates loop mode to keep Claude working until completion criteria pass.    |
| `/ticket-builder`                 | Spawns ticket-builder with task and worktree context for parallel execution.  |

### Rules (auto-loaded)

| Rule                        | Purpose                                                                  |
| --------------------------- | ------------------------------------------------------------------------ |
| `testing-standards.md`      | Prevents flaky tests and bad patterns so test results are trustworthy.   |
| `verification-standards.md` | Requires evidence before completion claims to stop hallucinated success. |
| `code-quality.md`           | Flags slop patterns and enforces hygiene so the codebase stays clean.    |

## Layout

```
autonomous-dev-kit/
  install.sh
  agents/
  skills/
  rules/
  hooks/
  lib/
  shell/
  templates/
  docs/
  examples/
```

## Docs

Start with `docs/GETTING_STARTED.md`, then keep `docs/WORKFLOW_REFERENCE.md` open while you run builds. If something breaks, `docs/TROUBLESHOOTING.md` is short and useful.

## Credits

This repo borrows the best ideas from [continuous-claude](https://github.com/samwho/continuous-claude) and the [Ralph Wiggum Claude Code plugin](https://github.com/abbitt/ralph-wiggum-claude) and then pushes them further by combining them with a bunch of other ideas I stole that I wish I could credit but I can't because once you refresh away a post on X, the algorithm ensures you shall never see it again.

## License

MIT.
