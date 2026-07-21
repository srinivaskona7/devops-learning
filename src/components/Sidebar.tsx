import { NavLink } from 'react-router-dom'
import { useState, useEffect } from 'react'
import { MODULES } from '../data/modules'
import { BookOpen, Menu, X, ChevronRight, CheckCircle } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

type Difficulty = 'beginner' | 'intermediate' | 'advanced' | 'expert'

interface ModuleShape {
  id: number | string
  slug: string
  title: string
  difficulty: Difficulty
  icon: any
}

interface ProgressMap {
  [slug: string]: number
}

const difficultyStyles: Record<Difficulty, string> = {
  beginner: 'bg-stitch-green/15 text-stitch-green border border-stitch-green/40',
  intermediate: 'bg-stitch-cyan/15 text-stitch-cyan border border-stitch-cyan/40',
  advanced: 'bg-amber-400/15 text-amber-300 border border-amber-400/40',
  expert: 'bg-fuchsia-400/15 text-fuchsia-300 border border-fuchsia-400/40',
}

const loadProgress = (): ProgressMap => {
  try {
    const raw = localStorage.getItem('devops-navigator:progress')
    if (!raw) return {}
    const parsed = JSON.parse(raw) as ProgressMap
    return parsed && typeof parsed === 'object' ? parsed : {}
  } catch {
    return {}
  }
}

export const Sidebar: React.FC = () => {
  const [mobileOpen, setMobileOpen] = useState(false)
  const [compact, setCompact] = useState(false)
  const [progress, setProgress] = useState<ProgressMap>({})

  useEffect(() => {
    setProgress(loadProgress())
    const onStorage = () => setProgress(loadProgress())
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const modulesList = MODULES as ModuleShape[]
  const totalModules = modulesList.length
  const completedModules = modulesList.filter(
    (m) => (progress[m.slug] ?? 0) >= 100
  ).length
  const overallPct = totalModules === 0
    ? 0
    : Math.round((completedModules / totalModules) * 100)

  const widthClass = compact ? 'w-20' : 'w-72'

  const SidebarBody = (
    <motion.aside
      key="sidebar-body"
      initial={{ opacity: 0, x: -12 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -12 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
      className={`glass-lg rounded-xl ${widthClass} h-[calc(100vh-120px)] sticky top-20 flex flex-col border border-stitch-cyan/20 overflow-hidden transition-[width] duration-300`}
    >
      {/* Header */}
      <div className="px-4 pt-4 pb-3 border-b border-stitch-cyan/15 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <div className="w-9 h-9 rounded-lg glass-sm flex items-center justify-center flex-shrink-0">
            <BookOpen className="w-4 h-4 text-stitch-cyan" />
          </div>
          {!compact && (
            <div className="min-w-0">
              <h2 className="text-xs font-bold text-stitch-cyan uppercase tracking-[0.18em] truncate">
                Course Modules
              </h2>
              <p className="text-[11px] text-stitch-text-muted truncate">
                {totalModules} total · {completedModules} complete
              </p>
            </div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setCompact((c) => !c)}
          aria-label={compact ? 'Expand sidebar' : 'Collapse sidebar'}
          aria-pressed={compact}
          className="p-1.5 rounded-md text-stitch-text-muted hover:text-stitch-cyan hover:bg-stitch-cyan/10 transition border border-transparent hover:border-stitch-cyan/30 flex-shrink-0"
        >
          <ChevronRight
            className={`w-4 h-4 transition-transform ${compact ? '' : 'rotate-180'}`}
          />
        </button>
      </div>

      {/* Progress indicator */}
      {!compact && (
        <div className="px-4 py-3 border-b border-stitch-cyan/15">
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[11px] uppercase tracking-wider text-stitch-text-muted">
              Progress
            </span>
            <span className="text-xs font-semibold text-stitch-cyan tabular-nums">
              {overallPct}%
            </span>
          </div>
          <div className="h-1.5 rounded-full bg-stitch-cyan/10 overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${overallPct}%` }}
              transition={{ duration: 0.6, ease: 'easeOut' }}
              className="h-full bg-gradient-to-r from-stitch-cyan to-stitch-green"
            />
          </div>
        </div>
      )}

      {/* Scroll area */}
      <nav
        className="flex-1 overflow-y-auto px-2 py-3 custom-scrollbar"
        aria-label="Course modules"
      >
        <ul className="space-y-1">
          {modulesList.map((module) => {
            const Icon = module.icon
            const modProgress = progress[module.slug] ?? 0
            const isComplete = modProgress >= 100

            return (
              <li key={module.id}>
                <NavLink
                  to={`/modules/${module.slug}`}
                  title={compact ? module.title : undefined}
                  className={({ isActive }) =>
                    [
                      'group flex items-center gap-3 rounded-lg transition-all border',
                      compact ? 'px-2 py-2 justify-center' : 'px-3 py-2.5',
                      isActive
                        ? 'bg-stitch-cyan/20 text-stitch-cyan border-stitch-cyan/50 shadow-[0_0_0_1px_rgba(0,229,255,0.15)]'
                        : 'text-stitch-text-secondary border-transparent hover:bg-stitch-cyan/10 hover:text-stitch-cyan hover:border-stitch-cyan/25',
                    ].join(' ')
                  }
                >
                  {({ isActive }) => (
                    <>
                      <div
                        className={`w-8 h-8 rounded-md flex items-center justify-center flex-shrink-0 transition ${
                          isActive
                            ? 'bg-stitch-cyan/25 text-stitch-cyan'
                            : 'bg-stitch-cyan/5 text-stitch-text-secondary group-hover:text-stitch-cyan'
                        }`}
                      >
                        {Icon ? (
                          <Icon className="w-4 h-4" />
                        ) : (
                          <BookOpen className="w-4 h-4" />
                        )}
                      </div>

                      {!compact && (
                        <div className="flex-1 min-w-0 flex items-center gap-2">
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5">
                              <span className="text-sm font-medium truncate">
                                {module.title}
                              </span>
                              {isComplete && (
                                <CheckCircle className="w-3.5 h-3.5 text-stitch-green flex-shrink-0" />
                              )}
                            </div>
                            <span
                              className={`inline-block mt-1 text-[10px] font-semibold uppercase tracking-wider px-1.5 py-0.5 rounded ${difficultyStyles[module.difficulty]}`}
                            >
                              {module.difficulty}
                            </span>
                          </div>
                          <ChevronRight
                            className={`w-4 h-4 flex-shrink-0 transition-transform ${
                              isActive ? 'translate-x-0.5 text-stitch-cyan' : 'text-stitch-text-muted group-hover:translate-x-0.5'
                            }`}
                          />
                        </div>
                      )}
                    </>
                  )}
                </NavLink>
              </li>
            )
          })}
        </ul>
      </nav>

      {!compact && (
        <div className="px-4 py-3 border-t border-stitch-cyan/15 text-[11px] text-stitch-text-muted">
          <span className="text-stitch-cyan font-semibold">{completedModules}</span>{' '}
          of <span className="text-stitch-text-secondary">{totalModules}</span> modules complete
        </div>
      )}
    </motion.aside>
  )

  return (
    <>
      {/* Mobile menu button */}
      <button
        type="button"
        onClick={() => setMobileOpen(true)}
        aria-label="Open navigation menu"
        aria-expanded={mobileOpen}
        className="lg:hidden fixed bottom-6 right-6 z-40 w-12 h-12 rounded-full glass-lg border border-stitch-cyan/40 text-stitch-cyan flex items-center justify-center shadow-glow-primary hover:shadow-glow-lg transition"
      >
        <Menu className="w-5 h-5" />
      </button>

      {/* Desktop sidebar (always visible) */}
      <div className="hidden lg:block">{SidebarBody}</div>

      {/* Mobile drawer */}
      <AnimatePresence>
        {mobileOpen && (
          <>
            <motion.div
              key="sidebar-overlay"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              onClick={() => setMobileOpen(false)}
              className="lg:hidden fixed inset-0 z-40 bg-stitch-dark/70 backdrop-blur-sm"
            />
            <motion.div
              key="sidebar-drawer"
              initial={{ x: '-100%' }}
              animate={{ x: 0 }}
              exit={{ x: '-100%' }}
              transition={{ type: 'tween', duration: 0.25, ease: 'easeOut' }}
              className="lg:hidden fixed inset-y-0 left-0 z-50 p-4 flex"
            >
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setMobileOpen(false)}
                  aria-label="Close navigation menu"
                  className="absolute -right-3 -top-3 z-10 w-8 h-8 rounded-full glass-sm border border-stitch-cyan/40 text-stitch-cyan flex items-center justify-center hover:bg-stitch-cyan/20 transition"
                >
                  <X className="w-4 h-4" />
                </button>
                {SidebarBody}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  )
}

export default Sidebar
