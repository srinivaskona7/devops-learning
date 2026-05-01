import './App.css'
import { Zap, GitBranch, BookOpen, Lightbulb, Cpu, Network } from 'lucide-react'

function App() {
  const modules = [
    { id: 1, title: "Linux Fundamentals", progress: 100, icon: BookOpen },
    { id: 2, title: "Docker & Containers", progress: 85, icon: Cpu },
    { id: 3, title: "Kubernetes Core", progress: 70, icon: Network },
    { id: 4, title: "Helm Charts", progress: 60, icon: GitBranch },
    { id: 5, title: "Monitoring & Observability", progress: 45, icon: Zap },
    { id: 6, title: "Security Best Practices", progress: 30, icon: Lightbulb },
  ]

  return (
    <div className="min-h-screen bg-stitch-dark text-stitch-text-primary overflow-hidden">
      {/* Glassmorphic Header */}
      <header className="sticky top-0 z-50 backdrop-blur-glass bg-stitch-surface border-b border-stitch-cyan/20">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg glass-sm flex items-center justify-center">
              <Zap className="w-6 h-6 text-stitch-cyan animate-glow" />
            </div>
            <h1 className="text-xl font-bold text-gradient">DevOps Navigator</h1>
          </div>
          <nav className="flex gap-6 text-sm">
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">Modules</a>
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">Projects</a>
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">Docs</a>
          </nav>
        </div>
      </header>

      {/* Hero Section */}
      <section className="max-w-7xl mx-auto px-6 py-12">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Hero Card - Span 2 columns */}
          <div className="lg:col-span-2 glass p-8 rounded-xl hover:shadow-glow-primary transition-all duration-300">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-4xl font-bold mb-4">
                  <span className="text-gradient">The Intelligent DevOps Navigator</span>
                </h2>
                <p className="text-stitch-text-secondary mb-6">
                  Master cloud infrastructure through hands-on learning. 15 modules, 10 real-world projects, and a curriculum designed for production excellence.
                </p>
                <button className="px-6 py-3 bg-gradient-to-r from-stitch-cyan to-stitch-green text-stitch-dark font-bold rounded-lg hover:shadow-glow-lg transition-all hover:translate-y-[-2px]">
                  Start Learning
                </button>
              </div>
            </div>

            {/* Pulsing cursor effect */}
            <div className="absolute right-8 top-8 w-12 h-12 rounded-full border-2 border-stitch-cyan/30 animate-pulse">
              <div className="absolute inset-2 rounded-full border border-stitch-cyan/60"></div>
            </div>
          </div>

          {/* Intelligence Widget - Span 1 column */}
          <div className="glass-lg p-6 rounded-xl flex flex-col justify-center">
            <h3 className="text-sm font-bold text-stitch-cyan mb-4 uppercase tracking-wide">System Architecture</h3>
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-stitch-cyan animate-pulse"></div>
                <span className="text-sm text-stitch-text-secondary">main()</span>
              </div>
              <div className="ml-4 h-6 w-0.5 bg-stitch-cyan/30"></div>
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-stitch-green"></div>
                <span className="text-sm text-stitch-text-secondary">get_conn()</span>
              </div>
              <div className="ml-4 h-6 w-0.5 bg-stitch-cyan/30"></div>
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-stitch-pink"></div>
                <span className="text-sm text-stitch-text-secondary">run_migrations()</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Bento Grid - Learning Journey */}
      <section className="max-w-7xl mx-auto px-6 py-12">
        <h2 className="text-2xl font-bold mb-8 text-gradient">Your Learning Journey</h2>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {modules.map((module, idx) => {
            const Icon = module.icon
            const isFeatured = idx % 3 === 0

            return (
              <div
                key={module.id}
                className={`glass rounded-xl p-6 cursor-pointer hover:shadow-glow-primary hover:translate-y-[-4px] transition-all duration-300 ${
                  isFeatured ? 'lg:col-span-1' : ''
                }`}
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="w-12 h-12 rounded-lg glass-sm flex items-center justify-center">
                    <Icon className="w-6 h-6 text-stitch-cyan" />
                  </div>
                  <span className="text-xs font-bold text-stitch-green bg-stitch-green/10 px-2 py-1 rounded">
                    {module.progress}%
                  </span>
                </div>

                <h3 className="text-base font-bold mb-3 text-stitch-text-primary">{module.title}</h3>

                {/* Progress Bar */}
                <div className="w-full h-2 bg-stitch-surface rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-stitch-cyan to-stitch-green transition-all duration-500"
                    style={{ width: `${module.progress}%` }}
                  ></div>
                </div>

                <p className="text-xs text-stitch-text-muted mt-3">
                  {module.progress === 100 ? '✓ Completed' : `${100 - module.progress}% remaining`}
                </p>
              </div>
            )
          })}
        </div>
      </section>

      {/* Quick Stats Section */}
      <section className="max-w-7xl mx-auto px-6 py-12 grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Modules', value: '15' },
          { label: 'Projects', value: '10' },
          { label: 'Hours Content', value: '120+' },
          { label: 'Community', value: '1K+' },
        ].map((stat, idx) => (
          <div key={idx} className="glass-sm p-6 rounded-lg text-center">
            <div className="text-2xl font-bold text-gradient mb-2">{stat.value}</div>
            <p className="text-xs text-stitch-text-muted uppercase tracking-wide">{stat.label}</p>
          </div>
        ))}
      </section>

      {/* Footer */}
      <footer className="border-t border-stitch-cyan/20 py-8">
        <div className="max-w-7xl mx-auto px-6 text-center text-sm text-stitch-text-muted">
          <p>© 2024 DevOps Learning Lab. Built with React + Vite + Stitch Design System.</p>
        </div>
      </footer>
    </div>
  )
}

export default App
