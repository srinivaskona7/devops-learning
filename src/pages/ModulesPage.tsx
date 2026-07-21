import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useState, useMemo } from 'react'
import { MODULES, type Difficulty } from '../data/modules'
import { Search, Clock, BookOpen, ChevronRight, ExternalLink, Lock } from 'lucide-react'

type FilterDifficulty = 'all' | Difficulty
type FilterStatus = 'all' | 'available' | 'coming-soon'

const difficultyStyles: Record<Difficulty, { badge: string; dot: string }> = {
  beginner: {
    badge: 'bg-stitch-green/10 text-stitch-green border-stitch-green/30',
    dot: 'bg-stitch-green',
  },
  intermediate: {
    badge: 'bg-stitch-cyan/10 text-stitch-cyan border-stitch-cyan/30',
    dot: 'bg-stitch-cyan',
  },
  advanced: {
    badge: 'bg-stitch-pink/10 text-stitch-pink border-stitch-pink/30',
    dot: 'bg-stitch-pink',
  },
  expert: {
    badge: 'bg-purple-400/10 text-purple-300 border-purple-400/30',
    dot: 'bg-purple-400',
  },
}

const DIFFICULTY_FILTERS: FilterDifficulty[] = ['all', 'beginner', 'intermediate', 'advanced']

const ModulesPage: React.FC = () => {
  const [difficulty, setDifficulty] = useState<FilterDifficulty>('all')
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all')
  const [query, setQuery] = useState<string>('')

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return MODULES.filter((m) => {
      if (difficulty !== 'all' && m.difficulty !== difficulty) return false
      if (statusFilter !== 'all' && m.status !== statusFilter) return false
      if (!q) return true
      return m.title.toLowerCase().includes(q) || m.description.toLowerCase().includes(q)
    })
  }, [difficulty, statusFilter, query])

  const availableCount = useMemo(() => MODULES.filter((m) => m.status === 'available').length, [])

  return (
    <div className="min-h-screen bg-stitch-dark text-stitch-text-primary">
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute -top-40 -left-40 h-[32rem] w-[32rem] rounded-full bg-stitch-cyan/10 blur-[120px]" />
        <div className="absolute top-1/3 -right-40 h-[28rem] w-[28rem] rounded-full bg-stitch-pink/10 blur-[120px]" />
      </div>

      <div className="relative mx-auto max-w-7xl px-6 pb-24 pt-12">
        <motion.header
          initial={{ opacity: 0, y: -12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="mb-10"
        >
          <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-stitch-cyan/30 bg-stitch-cyan/5 px-3 py-1 text-xs uppercase tracking-[0.18em] text-stitch-cyan">
            <span className="h-1.5 w-1.5 rounded-full bg-stitch-cyan shadow-glow-primary" />
            Curriculum
          </div>
          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl text-gradient">
            Module Catalog
          </h1>
          <p className="mt-4 max-w-2xl text-base text-stitch-text-secondary sm:text-lg">
            Explore {MODULES.length} hands-on DevOps modules. {availableCount} interactive now — the rest open inline in the reference docs. Each module follows the Reason, Thinking, Execution, Simulation, Output, and Use-case pattern.
          </p>
        </motion.header>

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
          className="glass mb-10 flex flex-col gap-4 rounded-2xl p-4 backdrop-blur-xl lg:flex-row lg:items-center lg:justify-between"
        >
          <div className="relative flex-1 lg:max-w-md">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-stitch-text-muted" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search modules..."
              className="w-full rounded-xl border border-stitch-cyan/20 bg-stitch-dark/50 py-2.5 pl-11 pr-4 text-sm text-stitch-text-primary placeholder-stitch-text-muted outline-none transition focus:border-stitch-cyan/60 focus:ring-2 focus:ring-stitch-cyan/20"
            />
          </div>

          <div className="flex flex-wrap gap-2">
            {(['all', 'available', 'coming-soon'] as FilterStatus[]).map((s) => {
              const isActive = statusFilter === s
              const label = s === 'all' ? 'All' : s === 'available' ? 'Interactive' : 'Docs-only'
              return (
                <button
                  key={s}
                  type="button"
                  onClick={() => setStatusFilter(s)}
                  className={`rounded-lg border px-4 py-2 text-xs font-medium uppercase tracking-wider transition ${
                    isActive
                      ? 'border-stitch-green/60 bg-stitch-green/15 text-stitch-green'
                      : 'border-stitch-cyan/20 bg-stitch-surface text-stitch-text-secondary hover:border-stitch-green/40 hover:text-stitch-green'
                  }`}
                >
                  {label}
                </button>
              )
            })}
            <div className="mx-1 w-px self-stretch bg-stitch-cyan/20" />
            {DIFFICULTY_FILTERS.map((level) => {
              const isActive = difficulty === level
              return (
                <button
                  key={level}
                  type="button"
                  onClick={() => setDifficulty(level)}
                  className={`rounded-lg border px-4 py-2 text-xs font-medium uppercase tracking-wider transition ${
                    isActive
                      ? 'border-stitch-cyan/60 bg-stitch-cyan/15 text-stitch-cyan'
                      : 'border-stitch-cyan/20 bg-stitch-surface text-stitch-text-secondary hover:border-stitch-cyan/40 hover:text-stitch-cyan'
                  }`}
                >
                  {level}
                </button>
              )
            })}
          </div>
        </motion.div>

        <div className="mb-6 text-xs uppercase tracking-wider text-stitch-text-muted">
          Showing <span className="text-stitch-cyan">{filtered.length}</span> of {MODULES.length}
        </div>

        {filtered.length === 0 ? (
          <div className="glass rounded-2xl p-16 text-center backdrop-blur-xl">
            <BookOpen className="mx-auto mb-4 h-10 w-10 text-stitch-text-muted" />
            <h3 className="mb-2 text-lg font-medium text-stitch-text-primary">No modules match your filters</h3>
            <p className="text-sm text-stitch-text-muted">Try a different search or difficulty.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
            {filtered.map((module, i) => {
              const styles = difficultyStyles[module.difficulty]
              const Icon = module.icon
              const isAvailable = module.status === 'available'

              const CardBody = (
                <>
                  <div className="relative mb-4 flex items-start justify-between">
                    <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-stitch-cyan/20 bg-stitch-surface transition-transform duration-300 group-hover:scale-110">
                      <Icon className="h-5 w-5 text-stitch-cyan" />
                    </div>
                    <div className="flex flex-col items-end gap-1.5">
                      <span
                        className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider ${styles.badge}`}
                      >
                        <span className={`h-1.5 w-1.5 rounded-full ${styles.dot}`} />
                        {module.difficulty}
                      </span>
                      {!isAvailable && (
                        <span className="inline-flex items-center gap-1 rounded-full border border-stitch-text-muted/30 bg-stitch-text-muted/10 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-stitch-text-muted">
                          <Lock className="h-2.5 w-2.5" />
                          Docs only
                        </span>
                      )}
                    </div>
                  </div>

                  <h3 className="relative mb-2 text-xl font-semibold tracking-tight text-stitch-text-primary transition-colors group-hover:text-stitch-cyan">
                    {module.title}
                  </h3>
                  <p className="relative mb-6 line-clamp-3 flex-1 text-sm leading-relaxed text-stitch-text-secondary">
                    {module.description}
                  </p>

                  <div className="relative mb-4 flex items-center gap-4 text-xs text-stitch-text-muted">
                    <span className="inline-flex items-center gap-1.5">
                      <Clock className="h-3.5 w-3.5" />
                      {module.estimatedHours}h
                    </span>
                    <span className="inline-flex items-center gap-1.5">
                      <BookOpen className="h-3.5 w-3.5" />
                      {module.prerequisites.length === 0
                        ? 'No prereqs'
                        : `${module.prerequisites.length} prereq${module.prerequisites.length === 1 ? '' : 's'}`}
                    </span>
                  </div>

                  <div className={`relative flex items-center justify-between border-t pt-4 text-sm font-medium ${isAvailable ? 'border-stitch-cyan/20 text-stitch-cyan' : 'border-stitch-text-muted/20 text-stitch-text-muted'}`}>
                    <span>{isAvailable ? 'Start module' : 'Open in docs'}</span>
                    {isAvailable ? (
                      <ChevronRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                    ) : (
                      <ExternalLink className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
                    )}
                  </div>
                </>
              )

              const cardClass = `glass group relative flex h-full flex-col overflow-hidden rounded-2xl p-6 backdrop-blur-xl transition-all duration-300 ${isAvailable ? 'hover:border-stitch-cyan/60 hover:shadow-glow-primary' : 'opacity-80 hover:opacity-100 hover:border-stitch-text-muted/40'}`

              return (
                <motion.div
                  key={module.slug}
                  initial={{ opacity: 0, y: 24, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  transition={{ duration: 0.4, delay: i * 0.05, ease: 'easeOut' }}
                  whileHover={{ y: -4 }}
                >
                  {isAvailable ? (
                    <Link to={`/modules/${module.slug}`} className={cardClass}>
                      {CardBody}
                    </Link>
                  ) : (
                    <a
                      href={`docs/${module.slug}/`}
                      className={cardClass}
                      aria-label={`Open ${module.title} in docs reference (not yet interactive)`}
                    >
                      {CardBody}
                    </a>
                  )}
                </motion.div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

export default ModulesPage
