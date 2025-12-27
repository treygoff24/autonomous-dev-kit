import type { Todo } from '@/types/todo';
import styles from './TodoItem.module.css';

interface TodoItemProps {
  todo: Todo;
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}

export function TodoItem({ todo, onToggle, onDelete }: TodoItemProps) {
  return (
    <li className={styles.item}>
      <label className={styles.label}>
        <input
          type="checkbox"
          className={styles.checkbox}
          checked={todo.completed}
          onChange={() => onToggle(todo.id)}
          aria-label={`Mark "${todo.text}" as ${todo.completed ? 'incomplete' : 'complete'}`}
        />
        <span className={styles.checkmark} aria-hidden="true" />
        <span
          className={`${styles.text} ${todo.completed ? styles.completed : ''}`}
          title={todo.text}
        >
          {todo.text}
        </span>
      </label>
      <button
        type="button"
        className={styles.deleteButton}
        onClick={() => onDelete(todo.id)}
        aria-label={`Delete "${todo.text}"`}
      >
        <span aria-hidden="true">&times;</span>
      </button>
    </li>
  );
}
