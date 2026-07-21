import { useCallback, useEffect, useState } from 'react'

/**
 * Client-side learning progress — persisted to localStorage (no backend,
 * GitHub-Pages friendly). Tracks completed module slugs + the last visited one.
 */
const KEY = 'dll:progress:v1'

interface ProgressState {
  completed: string[]
  last: string | null
}

function read(): ProgressState {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) return { completed: [], last: null, ...JSON.parse(raw) }
  } catch {
    /* ignore corrupt/unavailable storage */
  }
  return { completed: [], last: null }
}

function write(state: ProgressState) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state))
    // notify other hook instances in this tab
    window.dispatchEvent(new CustomEvent('dll:progress'))
  } catch {
    /* ignore */
  }
}

export function useProgress() {
  const [state, setState] = useState<ProgressState>(read)

  useEffect(() => {
    const sync = () => setState(read())
    window.addEventListener('dll:progress', sync)
    window.addEventListener('storage', sync)
    return () => {
      window.removeEventListener('dll:progress', sync)
      window.removeEventListener('storage', sync)
    }
  }, [])

  const isDone = useCallback((slug: string) => state.completed.includes(slug), [state.completed])

  const toggleDone = useCallback((slug: string) => {
    const next = read()
    next.completed = next.completed.includes(slug)
      ? next.completed.filter((s) => s !== slug)
      : [...next.completed, slug]
    write(next)
    setState(next)
  }, [])

  const visit = useCallback((slug: string) => {
    const next = read()
    if (next.last !== slug) {
      next.last = slug
      write(next)
      setState(next)
    }
  }, [])

  return {
    completed: state.completed,
    last: state.last,
    completedCount: state.completed.length,
    isDone,
    toggleDone,
    visit,
  }
}
