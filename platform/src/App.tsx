import './App.css'
import { useState } from 'react'
import { Zap, GitBranch, BookOpen, Lightbulb, Cpu, Network } from 'lucide-react'
import {
  BentoGrid,
  BentoItem,
  IntelligenceWidget,
  LearningJourneyCard,
  StatCard,
  CourseView
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
  const [isInCourseView, setIsInCourseView] = useState(false)

  const handleStartLearning = () => {
    setIsInCourseView(true)
  }

  const handleBackToHome = () => {
    setIsInCourseView(false)
  }

  if (isInCourseView) {
    return (
      <div className="min-h-screen bg-stitch-dark text-stitch-text-primary overflow-hidden">
        {/* Course View Header */}
        <header className="sticky top-0 z-50 backdrop-blur-glass bg-stitch-surface border-b border-stitch-cyan/20">
          <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
            <button
              onClick={handleBackToHome}
              className="flex items-center gap-3 hover:opacity-80 transition"
            >
              <div className="w-10 h-10 rounded-lg glass-sm flex items-center justify-center">
                <Zap className="w-6 h-6 text-stitch-cyan animate-glow" />
              </div>
              <h1 className="text-xl font-bold text-gradient">DevOps Navigator</h1>
            </button>
          </div>
        </header>

        {/* Course View Content */}
        <div className="max-w-7xl mx-auto">
          <CourseView onBackToHome={handleBackToHome} />
        </div>
      </div>
    )
  }

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
            <button
              onClick={() => setIsInCourseView(true)}
              className="text-stitch-text-secondary hover:text-stitch-cyan transition"
            >
              Modules
            </button>
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
            <div
              onClick={handleStartLearning}
              className="glass p-8 rounded-xl hover:shadow-glow-primary transition-all duration-300 relative overflow-hidden cursor-pointer"
            >
              <div className="relative z-10">
                <h2 className="text-4xl font-bold mb-4">
                  <span className="text-gradient">The Intelligent DevOps Navigator</span>
                </h2>
                <p className="text-stitch-text-secondary mb-6">
                  Master cloud infrastructure through hands-on learning. 15 modules, 10 real-world projects, and a curriculum designed for production excellence.
                </p>
                <button
                  onClick={handleStartLearning}
                  className="px-6 py-3 bg-gradient-to-r from-stitch-cyan to-stitch-green text-stitch-dark font-bold rounded-lg hover:shadow-glow-lg transition-all hover:translate-y-[-2px]"
                >
                  Start Learning
                </button>
              </div>

              {/* Animated pulsing cursor */}
              <div className="absolute right-8 top-8 w-12 h-12">
                <div className="absolute inset-0 rounded-full border-2 border-stitch-cyan/30 animate-pulse"></div>
                <div className="absolute inset-2 rounded-full border border-stitch-cyan/60"></div>
                <Zap className="absolute inset-3 w-6 h-6 text-stitch-cyan/50" />
              </div>
            </div>
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
