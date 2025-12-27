import type { Todo, Filter } from '@/types/todo';

const TODOS_KEY = 'todos';
const FILTER_KEY = 'todoFilter';

export function generateId(): string {
  return crypto.randomUUID();
}

export function loadTodos(): Todo[] {
  try {
    const stored = localStorage.getItem(TODOS_KEY);
    if (!stored) return [];
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed)) return [];
    return parsed;
  } catch {
    console.error('Failed to load todos from storage');
    return [];
  }
}

export function saveTodos(todos: Todo[]): void {
  try {
    localStorage.setItem(TODOS_KEY, JSON.stringify(todos));
  } catch (error) {
    console.error('Failed to save todos to storage:', error);
  }
}

export function loadFilter(): Filter {
  try {
    const stored = localStorage.getItem(FILTER_KEY);
    if (stored === 'all' || stored === 'active' || stored === 'completed') {
      return stored;
    }
    return 'all';
  } catch {
    return 'all';
  }
}

export function saveFilter(filter: Filter): void {
  try {
    localStorage.setItem(FILTER_KEY, filter);
  } catch (error) {
    console.error('Failed to save filter to storage:', error);
  }
}
