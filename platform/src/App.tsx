import './App.css'
import { Zap, GitBranch, BookOpen, Lightbulb, Cpu, Network } from 'lucide-react'
import {
  BentoGrid,
  BentoItem,
  HeroCard,
  IntelligenceWidget,
  LearningJourneyCard,
  StatCard
} from './components'

interface ModuleData {
  id: number
  title: string
  progress: number
  icon: any
}

const modules: ModuleData[] = [
  { id: 1, title: "Linux Fundamentals", progress: 100, icon: BookOpen },
  { id: 2, title: "Docker & Containers", progress: 85, icon: Cpu },
  { id: 3, title: "Kubernetes Core", progress: 70, icon: Network },
  { id: 4, title: "Helm Charts", progress: 60, icon: GitBranch },
  { id: 5, title: "Monitoring & Observability", progress: 45, icon: Zap },
  { id: 6, title: "Security Best Practices", progress: 30, icon: Lightbulb },
]

const stats = [
  { label: 'Modules', value: '15' },
  { label: 'Projects', value: '10' },
  { label: 'Hours Content', value: '120+' },
  { label: 'Community', value: '1K+' },
]

function App() {
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
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">
              Modules
            </a>
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">
              Projects
            </a>
            <a href="#" className="text-stitch-text-secondary hover:text-stitch-cyan transition">
              Docs
            </a>
          </nav>
        </div>
      </header>

      {/* Hero Section */}
      <section className="max-w-7xl mx-auto px-6 py-12">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Hero Card - Span 2 columns */}
          <div className="lg:col-span-2">
            <HeroCard />
          </div>

          {/* Intelligence Widget - Span 1 column */}
          <div>
            <IntelligenceWidget />
          </div>
        </div>
      </section>

      {/* Bento Grid - Learning Journey */}
      <section className="max-w-7xl mx-auto px-6 py-12">
        <h2 className="text-2xl font-bold mb-8 text-gradient">Your Learning Journey</h2>

        <BentoGrid>
          {modules.map((module) => (
            <BentoItem key={module.id}>
              <LearningJourneyCard
                title={module.title}
                progress={module.progress}
                icon={module.icon}
              />
            </BentoItem>
          ))}
        </BentoGrid>
      </section>

      {/* Quick Stats Section */}
      <section className="max-w-7xl mx-auto px-6 py-12 grid grid-cols-1 md:grid-cols-4 gap-4">
        {stats.map((stat, idx) => (
          <StatCard key={idx} label={stat.label} value={stat.value} />
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
