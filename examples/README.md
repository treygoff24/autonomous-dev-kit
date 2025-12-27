# Examples

This directory contains worked examples demonstrating the autonomous build workflow.

---

## todo-app

A complete worked example showing the full autonomous build cycle from spec to deployed feature.

### What This Demonstrates

- Complete spec with all required sections
- 4-phase implementation plan
- Context file showing mid-build state
- Build log with timestamps and review excerpts
- Clean, production-ready code
- Learnings captured from the build

### How to Study This Example

1. **Read the spec first** — `todo-app/SPEC.md`
   - Notice how requirements are precise and testable
   - See how edge cases and error states are defined

2. **Read the implementation plan** — `todo-app/IMPLEMENTATION_PLAN.md`
   - See how the spec is broken into phases
   - Notice phase sizing and dependencies

3. **Read the context file** — `todo-app/CONTEXT.md`
   - This shows state mid-build (Phase 3)
   - See how decisions and utilities are tracked

4. **Read the build log** — `todo-app/BUILD_LOG.md`
   - See realistic timestamps for each phase
   - Review excerpts show cross-agent interaction
   - Issues encountered and how they were resolved

5. **Read the learnings** — `todo-app/LEARNINGS.md`
   - Insights captured from the build
   - Patterns to apply to future builds

6. **Study the code** — `todo-app/src/`
   - Clean, well-structured React + TypeScript
   - Shows post-slop-removal quality

### How to Run the Example

```bash
cd examples/todo-app
npm install
npm run dev
```

Open http://localhost:5173 in your browser.

### Key Takeaways

1. **Specs need precision** — Vague requirements lead to rework
2. **4-5 phases is optimal** for this size project
3. **Context updates are critical** — The CONTEXT.md file prevented context loss
4. **Cross-agent reviews catch issues** — Both Claude and Codex found different problems
5. **Slop removal matters** — The final code is cleaner than the first pass
6. **Total time: ~75 minutes** — Complete build in one session

---

## Creating Your Own Examples

Use this example as a template:

1. Copy the spec structure from `todo-app/SPEC.md`
2. Break into phases like `todo-app/IMPLEMENTATION_PLAN.md`
3. Keep CONTEXT.md updated as you build
4. Capture learnings at the end

The more examples you study and create, the faster your autonomous builds will become.
