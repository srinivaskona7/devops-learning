import { NavLink, Outlet } from 'react-router-dom'
import { Terminal, BookOpen, Github } from 'lucide-react'
import { useProgress } from '../hooks/useProgress'

const DOCS_PATH = `${import.meta.env.BASE_URL || '/'}docs/`
const REPO_URL = 'https://github.com/srinivaskona7/devops-learning'
const TOTAL = 15

export default function AppLayout() {
  const { completedCount } = useProgress()

  const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    `text-sm font-medium transition-colors ${
      isActive ? 'text-stitch-cyan' : 'text-stitch-text-secondary hover:text-stitch-text-primary'
    }`

  return (
    <div className="flex min-h-screen flex-col">
      {/* Floating glass nav (offset from edges — HIG) */}
      <div className="sticky top-0 z-[10] px-3 pt-3 sm:px-4">
        <header className="glass-sm mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-2.5">
          <NavLink to="/" className="group flex items-center gap-2.5">
            <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-stitch-cyan/25 bg-stitch-cyan/10">
              <Terminal className="h-4 w-4 text-stitch-cyan" strokeWidth={2.4} />
            </span>
            <span className="font-display text-lg font-bold tracking-tight text-stitch-text-primary">
              DevOps<span className="text-stitch-cyan">Lab</span>
            </span>
          </NavLink>

          <nav className="flex items-center gap-5">
            <NavLink to="/" end className={navLinkClass}>Home</NavLink>
            <NavLink to="/modules" className={navLinkClass}>Modules</NavLink>
            <NavLink to="/about" className={navLinkClass}>About</NavLink>

            {completedCount > 0 && (
              <span
                className="hidden items-center gap-1.5 rounded-full border border-stitch-cyan/25 bg-stitch-cyan/5 px-2.5 py-1 font-mono text-[0.7rem] text-stitch-cyan sm:inline-flex"
                title="Modules you've marked complete"
              >
                {completedCount}/{TOTAL} done
              </span>
            )}

            <a
              href={DOCS_PATH}
              className="inline-flex items-center gap-1.5 rounded-lg border border-stitch-text-muted/20 px-3 py-1.5 text-sm font-medium text-stitch-text-secondary transition-colors hover:border-stitch-cyan/50 hover:text-stitch-cyan"
            >
              <BookOpen className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Docs</span>
            </a>
          </nav>
        </header>
      </div>

      <main className="flex-1">
        <Outlet />
      </main>

      <footer className="mt-auto border-t border-stitch-text-muted/10">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-6 py-7 text-sm text-stitch-text-muted sm:flex-row">
          <p className="font-mono text-xs">© {new Date().getFullYear()} DevOpsLab — learn by doing.</p>
          <div className="flex items-center gap-5">
            <a href={DOCS_PATH} className="inline-flex items-center gap-1.5 transition-colors hover:text-stitch-cyan">
              <BookOpen className="h-3.5 w-3.5" /> Reference docs
            </a>
            <a href={REPO_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 transition-colors hover:text-stitch-cyan">
              <Github className="h-3.5 w-3.5" /> GitHub
            </a>
          </div>
        </div>
      </footer>
    </div>
  )
}
