import { NavLink, Outlet } from 'react-router-dom'
import { Zap } from 'lucide-react'

const AppLayout = () => {
  const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    isActive
      ? 'text-stitch-cyan border-b-2 border-stitch-cyan pb-1 font-medium transition-colors'
      : 'text-stitch-text-secondary hover:text-stitch-cyan pb-1 transition-colors border-b-2 border-transparent'

  return (
    <div className="min-h-screen bg-stitch-dark text-stitch-text-primary flex flex-col">
      <header className="sticky top-0 z-50 backdrop-blur-glass bg-stitch-surface border-b border-stitch-cyan/20">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <NavLink to="/" className="flex items-center gap-2 group">
            <div className="p-2 rounded-lg bg-stitch-surface border border-stitch-cyan/20 group-hover:border-stitch-cyan/50 transition-colors">
              <Zap className="w-5 h-5 text-stitch-cyan animate-glow" strokeWidth={2.5} />
            </div>
            <span className="text-xl font-bold text-gradient tracking-tight">
              DevOps Navigator
            </span>
          </NavLink>

          <nav className="flex items-center gap-8">
            <NavLink to="/" end className={navLinkClass}>
              Home
            </NavLink>
            <NavLink to="/modules" className={navLinkClass}>
              Modules
            </NavLink>
            <NavLink to="/about" className={navLinkClass}>
              About
            </NavLink>
          </nav>
        </div>
      </header>

      <main className="flex-1 w-full">
        <Outlet />
      </main>

      <footer className="border-t border-stitch-cyan/20 bg-stitch-surface/30 backdrop-blur-sm mt-auto">
        <div className="max-w-7xl mx-auto px-6 py-6 flex flex-col sm:flex-row items-center justify-between gap-2 text-sm text-stitch-text-muted">
          <p>© {new Date().getFullYear()} DevOps Navigator. All rights reserved.</p>
          <p>Built with React + Vite + Stitch Design System</p>
        </div>
      </footer>
    </div>
  )
}

export default AppLayout
