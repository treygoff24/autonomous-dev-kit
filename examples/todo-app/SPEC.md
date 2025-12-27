# Todo App Specification

## Problem Statement

I need a simple, clean todo application to track daily tasks. It should work in the browser, persist data locally, and provide a pleasant user experience without requiring a backend.

## Scope

### In Scope

- Add tasks with a description
- Mark tasks as complete/incomplete (toggle)
- Delete tasks
- Filter tasks by status (all, active, completed)
- Clear all completed tasks
- Persist tasks to localStorage
- Responsive design (mobile and desktop)
- Keyboard navigation

### Out of Scope

- User accounts/authentication
- Cloud sync
- Due dates or priorities
- Categories or tags
- Drag-and-drop reordering
- Subtasks

## User Stories

### As a user, I want to:

1. **Add a task** so I can track what needs doing
   - Type in the input field, press Enter or click Add
   - Task appears at the bottom of the list
   - Input clears after adding

2. **Mark a task complete** so I can track progress
   - Click the checkbox to toggle completion
   - Completed tasks show with strikethrough styling
   - Task remains in list but visually distinct

3. **Delete a task** so I can remove items I no longer need
   - Click the delete button on a task
   - Task is removed immediately
   - No confirmation required (undo not needed)

4. **Filter tasks** so I can focus on what's relevant
   - Three filter options: All, Active, Completed
   - Filter is applied immediately on selection
   - Active filter persists across page refreshes

5. **Clear completed tasks** so I can clean up the list
   - Click "Clear Completed" button
   - All completed tasks are removed
   - Active tasks remain

6. **See my tasks after refreshing** so I don't lose my work
   - Tasks persist in localStorage
   - Page refresh restores all tasks
   - Filter preference also persists

## Technical Approach

- **Framework:** React 18 with TypeScript
- **Build tool:** Vite
- **Styling:** CSS Modules (no external CSS framework)
- **State:** React useState + custom hook for todo logic
- **Persistence:** localStorage with JSON serialization
- **Testing:** Vitest for unit tests

### Architecture

```
src/
├── components/
│   ├── TodoApp.tsx        # Main container
│   ├── TodoInput.tsx      # Input for new tasks
│   ├── TodoList.tsx       # List container
│   ├── TodoItem.tsx       # Individual task
│   └── TodoFilters.tsx    # Filter buttons
├── hooks/
│   └── useTodos.ts        # Todo state and persistence
├── types/
│   └── todo.ts            # Type definitions
├── utils/
│   └── storage.ts         # localStorage helpers
└── App.tsx                # Root component
```

## Data Model

### Todo

```typescript
interface Todo {
  id: string;           // UUID, generated on creation
  text: string;         // Task description, required, max 200 chars
  completed: boolean;   // Completion status, default false
  createdAt: string;    // ISO 8601 timestamp
}
```

### Filter

```typescript
type Filter = 'all' | 'active' | 'completed';
```

### Storage Schema

```typescript
// localStorage key: 'todos'
// Value: JSON array of Todo objects

// localStorage key: 'todoFilter'
// Value: Filter string
```

## UI/UX Requirements

### Layout

- Centered container, max-width 600px
- Clean white/gray color scheme
- Subtle shadows for depth
- Responsive: full width on mobile, centered on desktop

### Components

#### Header
- App title: "todos" (lowercase, large)
- Subtitle: task count ("3 items left")

#### Input
- Full-width text input
- Placeholder: "What needs to be done?"
- Add button (or Enter key)
- Focus on page load

#### Todo Item
- Checkbox on left (custom styled)
- Text in middle (strikethrough when complete)
- Delete button on right (appears on hover, always visible on mobile)
- Completed items have muted text color

#### Filters
- Three buttons: All, Active, Completed
- Current filter highlighted
- Bottom of list

#### Footer
- "Clear Completed" button (only visible when completed tasks exist)
- Shows count of active tasks

### States

| State | Appearance |
|-------|------------|
| Empty (no tasks) | Show "No tasks yet. Add one above!" |
| Loading | Brief loading indicator (though localStorage is fast) |
| All complete | Show celebration message |
| Error (storage) | Show error toast, fallback to memory-only |

### Interactions

- **Hover:** Delete button appears, item slightly highlights
- **Focus:** Visible focus ring on all interactive elements
- **Keyboard:** Tab navigates, Enter/Space activates, Escape clears input
- **Mobile:** Tap targets at least 44px, swipe not needed

## Acceptance Criteria

### Functional

- [ ] Typing text and pressing Enter adds a task with that text
- [ ] Clicking Add button adds a task with input text
- [ ] Clicking checkbox toggles task completion
- [ ] Clicking delete button removes the task
- [ ] Selecting a filter shows only matching tasks
- [ ] "Clear Completed" removes all completed tasks
- [ ] Tasks persist across page refresh
- [ ] Filter preference persists across page refresh
- [ ] Empty input does not add a task (validation)
- [ ] Text longer than 200 chars is truncated or rejected

### Non-Functional

- [ ] Page loads in under 2 seconds
- [ ] All interactive elements are keyboard accessible
- [ ] Color contrast meets WCAG AA (4.5:1)
- [ ] Works in Chrome, Firefox, Safari latest versions
- [ ] Responsive from 320px to 1920px width

## Edge Cases

### Input Validation
- Empty input: Do nothing, keep focus on input
- Whitespace-only input: Treat as empty
- Very long input (>200 chars): Truncate to 200 chars with "..." or reject with error

### Storage
- localStorage unavailable (private browsing): Fallback to memory-only, show warning
- Corrupted storage data: Reset to empty array, log error
- Storage quota exceeded: Show error, don't add task

### Display
- Very long task text: Truncate with ellipsis, show full on hover (title attribute)
- Many tasks (100+): Virtual scrolling not required, but list should remain performant

## Non-Functional Requirements

### Performance
- Initial render: < 100ms
- Add/delete/toggle: < 50ms perceived response
- No layout shifts during interactions

### Accessibility
- All controls keyboard accessible
- Screen reader announces task additions/completions
- Focus management on add/delete
- Reduced motion support

### Browser Support
- Chrome 90+
- Firefox 90+
- Safari 14+
- Edge 90+
