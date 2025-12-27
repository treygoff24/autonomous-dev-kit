import { useTodos } from '@/hooks/useTodos';
import { TodoInput } from './TodoInput';
import { TodoList } from './TodoList';
import { TodoFilters } from './TodoFilters';
import styles from './TodoApp.module.css';

export function TodoApp() {
  const {
    filteredTodos,
    filter,
    addTodo,
    toggleTodo,
    deleteTodo,
    clearCompleted,
    setFilter,
    activeCount,
    completedCount,
  } = useTodos();

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <h1 className={styles.title}>todos</h1>
        <p className={styles.subtitle} aria-live="polite">
          {activeCount} {activeCount === 1 ? 'item' : 'items'} left
        </p>
      </header>

      <main className={styles.main}>
        <TodoInput onAdd={addTodo} />
        <TodoList
          todos={filteredTodos}
          onToggle={toggleTodo}
          onDelete={deleteTodo}
        />
        <TodoFilters
          filter={filter}
          onFilterChange={setFilter}
          completedCount={completedCount}
          onClearCompleted={clearCompleted}
        />
      </main>
    </div>
  );
}
