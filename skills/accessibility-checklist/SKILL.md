---
name: accessibility-checklist
description: "Run accessibility checks on interactive UI components. Use after implementing UI, before code review. Creates TodoWrite items for each check. Covers WCAG AA compliance: labels, keyboard nav, focus, color contrast, motion, and content."
---

# Accessibility Checklist

Run accessibility checks on every interactive component before code review.

## When to Use

- After implementing any interactive UI component
- Before requesting code review
- When auditing existing UI for accessibility gaps

## How to Use

**Announce:** "I'm using the accessibility-checklist skill to verify this component."

**Create TodoWrite items** for each applicable check below. Mark as you verify.

## Required Checks

### Labels and Roles

Create todos for each:
- [ ] `aria-label` on icon buttons, inputs without visible labels, sliders
- [ ] `role` attribute when not using semantic HTML elements
- [ ] `aria-live` on dynamic content (toasts, loading states, live updates)
- [ ] Form labels connected via `htmlFor`/`id`

### Keyboard Navigation

- [ ] Enter/Space activates buttons and interactive elements
- [ ] Escape dismisses modals, dropdowns, popovers
- [ ] Arrow keys navigate within composite widgets (tabs, menus, sliders)
- [ ] Tab order follows logical reading order
- [ ] No keyboard traps (can always tab out of components)

### Visual

- [ ] Visible focus styles using `:focus-visible`
- [ ] Color contrast meets WCAG AA (4.5:1 for text, 3:1 for UI)
- [ ] Information not conveyed by color alone
- [ ] Touch targets at least 44x44px

### Motion and Animation

- [ ] Reduced motion support via `prefers-reduced-motion`
- [ ] No auto-playing animations that can't be paused
- [ ] No flashing content (seizure risk)

### Content

- [ ] Images have meaningful alt text (or empty alt="" for decorative)
- [ ] Headings follow hierarchical order (h1 → h2 → h3)
- [ ] Links have descriptive text (not "click here")
- [ ] Error messages are clear and associated with their fields

## Quick Test

Before marking complete, perform these manual checks:

1. **Keyboard-only test:** Navigate the entire feature without a mouse
2. **Screen reader spot-check:** Turn on VoiceOver (Mac) or NVDA (Windows) and verify key flows
3. **Zoom test:** Set browser to 200% zoom and verify layout doesn't break

## Common Fixes

**Icon button without label:**
```tsx
<button aria-label="Close modal" onClick={onClose}>
  <XIcon />
</button>
```

**Live region for dynamic content:**
```tsx
<div aria-live="polite" aria-atomic="true">
  {statusMessage}
</div>
```

**Reduced motion support:**
```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

**Focus visible styles:**
```css
button:focus-visible {
  outline: 2px solid var(--focus-ring-color);
  outline-offset: 2px;
}
```

## Workflow

1. Identify all interactive elements in the component
2. Create TodoWrite with applicable checks
3. Test each item, marking complete or fixing issues
4. Run the Quick Test manually
5. Report any items that couldn't be verified

## Output

After verification, provide:
- **Verdict:** Passes / Needs fixes
- **Issues fixed:** What you corrected during the check
- **Manual test results:** Keyboard, screen reader, zoom outcomes
- **Remaining issues:** Anything that needs user attention
