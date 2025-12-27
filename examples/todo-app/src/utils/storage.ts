import type { Todo, Filter } from '@/types/todo';

const TODOS_KEY = 'todos';
const FILTER_KEY = 'todoFilter';

function isValidTodo(value: unknown): value is Todo {
  if (!value || typeof value !== 'object') return false;
  const record = value as Record<string, unknown>;
  return (
    typeof record.id === 'string' &&
    typeof record.text === 'string' &&
    typeof record.completed === 'boolean' &&
    typeof record.createdAt === 'string'
  );
}

function fallbackUuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (char) => {
    const random = Math.floor(Math.random() * 16);
    const value = char === 'x' ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
}

export function generateId(): string {
  const cryptoObj = globalThis.crypto;

  if (cryptoObj?.randomUUID) {
    return cryptoObj.randomUUID();
  }

  if (cryptoObj?.getRandomValues) {
    const bytes = new Uint8Array(16);
    cryptoObj.getRandomValues(bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    const hex = Array.from(bytes, (byte) =>
      byte.toString(16).padStart(2, '0')
    );

    return `${hex[0]}${hex[1]}${hex[2]}${hex[3]}-${hex[4]}${hex[5]}-${hex[6]}${hex[7]}-${hex[8]}${hex[9]}-${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}`;
  }

  return fallbackUuid();
}

export function loadTodos(): Todo[] {
  try {
    const stored = localStorage.getItem(TODOS_KEY);
    if (!stored) return [];
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isValidTodo);
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
