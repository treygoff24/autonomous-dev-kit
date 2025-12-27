# Repository Guidelines

This repository is a bootstrap kit for autonomous AI-assisted development. Keep contributions scoped to documentation, templates, shell tooling, and the example app.

## Project Structure & Module Organization

- `docs/` holds workflow docs like `GETTING_STARTED.md` and `WORKFLOW_REFERENCE.md`.
- `templates/` contains protocol and checklist templates (e.g., `SPEC_WRITING.md`).
- `shell/` provides aliases and helper functions used by the workflow.
- `examples/todo-app/` is a worked React + TypeScript example with its own build pipeline.
- `skills/` is optional, and stores Claude Code skills.
- Root scripts and meta files live alongside `README.md`, `CHANGELOG.md`, and `install.sh`.

## Build, Test, and Development Commands

- `./install.sh` installs CLI tools and the Claude Code CLI, and wires up shell config.
- Example app workflow:
  - `cd examples/todo-app`
  - `npm install`
  - `npm run dev` (Vite dev server)
  - `npm run build` (TypeScript + Vite build)
  - `npm run lint` (ESLint)
  - `npm run typecheck` (TypeScript `--noEmit`)
  - `npm run test` / `npm run test:watch` (Vitest)

## Coding Style & Naming Conventions

- Match existing formatting in each file; JSON and TS/JS use 2-space indentation.
- Shell scripts are bash-first and typically use `set -euo pipefail`.
- Keep Markdown concise, with ATX headings and fenced code blocks with language tags.
- Example app tests follow `*.test.ts` or `*.test.tsx` naming (e.g., `storage.test.ts`).

## Testing Guidelines

- The example app uses Vitest and Testing Library; tests live under `examples/todo-app/src/`.
- Run `npm run test` when changing example app logic or utilities.
- Documentation and templates do not require tests, but ensure links and paths stay valid.

## Commit & Pull Request Guidelines

- Use Conventional Commit prefixes such as `feat:`, `fix:`, `chore:`; helpers in `shell/functions.zsh` align with this.
- PRs should include a short summary, key files touched (e.g., `templates/`, `docs/`), and test results.
- Include screenshots or screen recordings for UI changes in `examples/todo-app`.

## Security & Configuration Tips

- Do not commit API keys or local config. Personal settings belong in `~/.claude/` or a local `.claude/` directory.
- Keep `install.sh` idempotent and avoid destructive changes.
