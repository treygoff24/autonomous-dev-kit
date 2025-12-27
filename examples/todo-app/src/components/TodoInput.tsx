import { useState, useRef, useEffect, type KeyboardEvent } from 'react';
import styles from './TodoInput.module.css';

interface TodoInputProps {
  onAdd: (text: string) => void;
}

export function TodoInput({ onAdd }: TodoInputProps) {
  const [value, setValue] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const handleSubmit = () => {
    const trimmed = value.trim();
    if (trimmed) {
      onAdd(trimmed);
      setValue('');
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      setValue('');
    }
  };

  return (
    <div className={styles.container}>
      <input
        ref={inputRef}
        type="text"
        className={styles.input}
        placeholder="What needs to be done?"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKeyDown}
        aria-label="New todo"
        maxLength={200}
      />
      <button
        type="button"
        className={styles.button}
        onClick={handleSubmit}
        aria-label="Add todo"
      >
        Add
      </button>
    </div>
  );
}
