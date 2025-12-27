import type { Filter } from '@/types/todo';
import styles from './TodoFilters.module.css';

interface TodoFiltersProps {
  filter: Filter;
  onFilterChange: (filter: Filter) => void;
  completedCount: number;
  onClearCompleted: () => void;
}

const FILTERS: { value: Filter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'active', label: 'Active' },
  { value: 'completed', label: 'Completed' },
];

export function TodoFilters({
  filter,
  onFilterChange,
  completedCount,
  onClearCompleted,
}: TodoFiltersProps) {
  return (
    <footer className={styles.footer}>
      <div className={styles.filters} role="group" aria-label="Filter tasks">
        {FILTERS.map(({ value, label }) => (
          <button
            key={value}
            type="button"
            className={`${styles.filterButton} ${filter === value ? styles.active : ''}`}
            onClick={() => onFilterChange(value)}
            aria-pressed={filter === value}
          >
            {label}
          </button>
        ))}
      </div>
      {completedCount > 0 && (
        <button
          type="button"
          className={styles.clearButton}
          onClick={onClearCompleted}
        >
          Clear Completed
        </button>
      )}
    </footer>
  );
}
