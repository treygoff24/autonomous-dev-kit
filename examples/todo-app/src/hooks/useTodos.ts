import { useState, useEffect, useMemo, useCallback } from 'react';
import type { Todo, Filter } from '@/types/todo';
import {
  generateId,
  loadTodos,
  saveTodos,
  loadFilter,
  saveFilter,
} from '@/utils/storage';

export interface UseTodosReturn {
  todos: Todo[];
  filteredTodos: Todo[];
  filter: Filter;
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  deleteTodo: (id: string) => void;
  clearCompleted: () => void;
  setFilter: (filter: Filter) => void;
  activeCount: number;
  completedCount: number;
}

export function useTodos(): UseTodosReturn {
  const [todos, setTodos] = useState<Todo[]>(() => loadTodos());
  const [filter, setFilterState] = useState<Filter>(() => loadFilter());

  useEffect(() => {
    saveTodos(todos);
  }, [todos]);

  useEffect(() => {
    saveFilter(filter);
  }, [filter]);

  const addTodo = useCallback((text: string) => {
    const trimmed = text.trim();
    if (!trimmed) return;

    const newTodo: Todo = {
      id: generateId(),
      text: trimmed.slice(0, 200),
      completed: false,
      createdAt: new Date().toISOString(),
    };

    setTodos((prev) => [...prev, newTodo]);
  }, []);

  const toggleTodo = useCallback((id: string) => {
    setTodos((prev) =>
      prev.map((todo) =>
        todo.id === id ? { ...todo, completed: !todo.completed } : todo
      )
    );
  }, []);

  const deleteTodo = useCallback((id: string) => {
    setTodos((prev) => prev.filter((todo) => todo.id !== id));
  }, []);

  const clearCompleted = useCallback(() => {
    setTodos((prev) => prev.filter((todo) => !todo.completed));
  }, []);

  const setFilter = useCallback((newFilter: Filter) => {
    setFilterState(newFilter);
  }, []);

  const filteredTodos = useMemo(() => {
    switch (filter) {
      case 'active':
        return todos.filter((todo) => !todo.completed);
      case 'completed':
        return todos.filter((todo) => todo.completed);
      default:
        return todos;
    }
  }, [todos, filter]);

  const activeCount = useMemo(
    () => todos.filter((todo) => !todo.completed).length,
    [todos]
  );

  const completedCount = useMemo(
    () => todos.filter((todo) => todo.completed).length,
    [todos]
  );

  return {
    todos,
    filteredTodos,
    filter,
    addTodo,
    toggleTodo,
    deleteTodo,
    clearCompleted,
    setFilter,
    activeCount,
    completedCount,
  };
}
