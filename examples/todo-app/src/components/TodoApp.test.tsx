import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, beforeEach } from 'vitest';
import { TodoApp } from './TodoApp';

const addTodo = (text: string) => {
  const input = screen.getByLabelText('New todo');
  fireEvent.change(input, { target: { value: text } });
  fireEvent.keyDown(input, { key: 'Enter', code: 'Enter', charCode: 13 });
};

describe('TodoApp', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('adds a todo and updates the count', () => {
    render(<TodoApp />);

    addTodo('Buy milk');

    expect(screen.getByText('Buy milk')).toBeInTheDocument();
    expect(screen.getByText(/1 item left/i)).toBeInTheDocument();
    expect(screen.queryByText(/no tasks yet/i)).not.toBeInTheDocument();
  });

  it('toggles completion and filters tasks', () => {
    render(<TodoApp />);

    addTodo('First task');
    addTodo('Second task');

    const firstCheckbox = screen.getByRole('checkbox', {
      name: /mark "first task"/i,
    });
    fireEvent.click(firstCheckbox);

    fireEvent.click(screen.getByRole('button', { name: 'Completed' }));
    expect(screen.getByText('First task')).toBeInTheDocument();
    expect(screen.queryByText('Second task')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Active' }));
    expect(screen.getByText('Second task')).toBeInTheDocument();
    expect(screen.queryByText('First task')).not.toBeInTheDocument();
  });

  it('clears completed tasks', () => {
    render(<TodoApp />);

    addTodo('Task to clear');
    addTodo('Task to keep');

    const checkbox = screen.getByRole('checkbox', {
      name: /mark "task to clear"/i,
    });
    fireEvent.click(checkbox);

    fireEvent.click(screen.getByRole('button', { name: 'Clear Completed' }));

    expect(screen.queryByText('Task to clear')).not.toBeInTheDocument();
    expect(screen.getByText('Task to keep')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Clear Completed' })
    ).not.toBeInTheDocument();
  });
});
