import { describe, it, expect, beforeEach } from 'vitest';
import { loadTodos, saveTodos, loadFilter, saveFilter, generateId } from './storage';

describe('storage utilities', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  describe('generateId', () => {
    it('generates a valid UUID', () => {
      const id = generateId();
      expect(id).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      );
    });

    it('generates unique IDs', () => {
      const id1 = generateId();
      const id2 = generateId();
      expect(id1).not.toBe(id2);
    });
  });

  describe('loadTodos', () => {
    it('returns empty array when no todos stored', () => {
      expect(loadTodos()).toEqual([]);
    });

    it('returns stored todos', () => {
      const todos = [
        { id: '1', text: 'Test', completed: false, createdAt: '2024-01-01' },
      ];
      localStorage.setItem('todos', JSON.stringify(todos));
      expect(loadTodos()).toEqual(todos);
    });

    it('returns empty array on corrupted JSON', () => {
      localStorage.setItem('todos', 'not valid json');
      expect(loadTodos()).toEqual([]);
    });

    it('returns empty array when stored value is not an array', () => {
      localStorage.setItem('todos', JSON.stringify({ not: 'an array' }));
      expect(loadTodos()).toEqual([]);
    });

    it('filters out invalid todo entries', () => {
      const todos = [
        { id: '1', text: 'Valid', completed: false, createdAt: '2024-01-01' },
        { id: 2, text: 'Bad id', completed: false, createdAt: '2024-01-01' },
        { id: '3', text: 'Bad completed', completed: 'no', createdAt: '2024-01-01' },
        { id: '4', text: 'Missing createdAt', completed: false },
      ];
      localStorage.setItem('todos', JSON.stringify(todos));
      expect(loadTodos()).toEqual([
        { id: '1', text: 'Valid', completed: false, createdAt: '2024-01-01' },
      ]);
    });
  });

  describe('saveTodos', () => {
    it('saves todos to localStorage', () => {
      const todos = [
        { id: '1', text: 'Test', completed: false, createdAt: '2024-01-01' },
      ];
      saveTodos(todos);
      expect(JSON.parse(localStorage.getItem('todos') || '[]')).toEqual(todos);
    });
  });

  describe('loadFilter', () => {
    it('returns "all" when no filter stored', () => {
      expect(loadFilter()).toBe('all');
    });

    it('returns stored filter', () => {
      localStorage.setItem('todoFilter', 'active');
      expect(loadFilter()).toBe('active');
    });

    it('returns "all" for invalid filter value', () => {
      localStorage.setItem('todoFilter', 'invalid');
      expect(loadFilter()).toBe('all');
    });
  });

  describe('saveFilter', () => {
    it('saves filter to localStorage', () => {
      saveFilter('completed');
      expect(localStorage.getItem('todoFilter')).toBe('completed');
    });
  });
});
