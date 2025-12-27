# Accessibility Checklist

> Run this for every interactive component before requesting code review.

---

## Required Checks

### Labels and Roles
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

---

## Quick Test

Before calling for review:

1. **Keyboard-only test:** Unplug your mouse and navigate the entire feature
2. **Screen reader spot-check:** Turn on VoiceOver (Mac) or NVDA (Windows) and verify key flows make sense
3. **Zoom test:** Set browser to 200% zoom and verify layout doesn't break

---

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
