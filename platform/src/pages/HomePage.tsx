import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { ArrowRight, Play, Sparkles, Clock, Users, BookOpen, Layers, Zap } from 'lucide-react'
import { MODULES } from '../data/modules'

const stats = [
  { label: 'Modules', value: '15', icon: BookOpen },
  { label: 'Projects', value: '10', icon: Layers },
  { label: 'Hours Content', value: '120+', icon: Clock },
  { label: 'Community', value: '1K+', icon: Users },
]

const difficultyStyles: Record<string, string> = {
  beginner: 'bg-stitch-green/10 text-stitch-green border-stitch-green/30',
  intermediate: 'bg-stitch-cyan/10 text-stitch-cyan border-stitch-cyan/30',
  advanced: 'bg-stitch-pink/10 text-stitch-pink border-stitch-pink/30',
  expert: 'bg-purple-400/10 text-purple-300 border-purple-400/30',
}

const HomePage: React.FC = () => {
  const featuredModules = MODULES.slice(0, 6)

  return (
    <div className="min-h-screen bg-stitch-dark text-stitch-text-primary">
      {/* Ambient background */}
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute -top-40 -left-40 h-[500px] w-[500px] rounded-full bg-stitch-cyan/10 blur-[120px]" />
        <div className="absolute top-1/3 -right-40 h-[500px] w-[500px] rounded-full bg-stitch-pink/10 blur-[120px]" />
        <div className="absolute bottom-0 left-1/3 h-[400px] w-[400px] rounded-full bg-purple-500/10 blur-[120px]" />
      </div>

      {/* Hero */}
      <section className="relative mx-auto max-w-7xl px-6 pt-20 pb-12 lg:pt-28">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: 'easeOut' }}
          className="text-center"
        >
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-stitch-cyan/30 bg-stitch-cyan/5 px-4 py-1.5 text-xs font-medium tracking-wide text-stitch-cyan backdrop-blur">
            <Sparkles className="h-3.5 w-3.5" />
            <span>Learn by doing. Ship with confidence.</span>
          </div>

          <h1 className="text-gradient mx-auto max-w-5xl text-5xl font-bold leading-[1.05] tracking-tight sm:text-6xl lg:text-7xl">
            The Intelligent DevOps Navigator
          </h1>

          <p className="mx-auto mt-6 max-w-2xl text-lg text-stitch-text-secondary sm:text-xl">
            Master cloud infrastructure through hands-on learning. 15 modules, 10 real-world projects, a curriculum designed for production excellence.
          </p>

          <div className="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
            <Link
              to="/modules/01-linux"
              className="group inline-flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-stitch-cyan to-stitch-green px-7 py-3.5 text-sm font-bold text-stitch-dark shadow-glow-primary transition-all hover:scale-[1.02] hover:shadow-glow-lg"
            >
              <Play className="h-4 w-4" />
              Start Learning
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </Link>

            <Link
              to="/modules"
              className="group inline-flex items-center justify-center gap-2 rounded-xl border border-stitch-cyan/30 bg-stitch-surface px-7 py-3.5 text-sm font-semibold text-stitch-cyan backdrop-blur transition-all hover:border-stitch-cyan/60 hover:bg-stitch-cyan/10"
            >
              View Modules
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </Link>
          </div>
        </motion.div>

        {/* Stats row */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="mt-16 grid grid-cols-2 gap-4 sm:grid-cols-4 sm:gap-6"
        >
          {stats.map((stat) => {
            const Icon = stat.icon
            return (
              <div
                key={stat.label}
                className="glass rounded-2xl p-5 text-center backdrop-blur-xl"
              >
                <Icon className="mx-auto mb-2 h-5 w-5 text-stitch-cyan" />
                <div className="text-2xl font-bold tracking-tight text-gradient sm:text-3xl">
                  {stat.value}
                </div>
                <div className="mt-1 text-xs uppercase tracking-wider text-stitch-text-muted">
                  {stat.label}
                </div>
              </div>
            )
          })}
        </motion.div>
      </section>

      {/* Featured modules */}
      <section className="relative mx-auto max-w-7xl px-6 pb-20">
        <div className="mb-10 flex items-end justify-between">
          <div>
            <div className="mb-2 text-xs uppercase tracking-[0.2em] text-stitch-cyan">
              Featured Modules
            </div>
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl text-stitch-text-primary">
              Pick your next skill
            </h2>
          </div>
          <Link
            to="/modules"
            className="hidden items-center gap-1.5 text-sm font-medium text-stitch-cyan hover:text-stitch-green transition-colors sm:inline-flex"
          >
            Browse all
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>

        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {featuredModules.map((module, i) => {
            const Icon = module.icon
            return (
              <motion.div
                key={module.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: i * 0.08, ease: 'easeOut' }}
              >
                <Link
                  to={`/modules/${module.slug}`}
                  className="glass group relative block overflow-hidden rounded-2xl p-6 backdrop-blur-xl transition-all hover:border-stitch-cyan/60 hover:-translate-y-1 hover:shadow-glow-primary"
                >
                  <div className="relative">
                    <div className="flex items-start justify-between">
                      <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-stitch-cyan/20 bg-stitch-surface">
                        <Icon className="h-5 w-5 text-stitch-cyan" />
                      </div>
                      <span
                        className={`rounded-full border px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider ${difficultyStyles[module.difficulty]}`}
                      >
                        {module.difficulty}
                      </span>
                    </div>

                    <h3 className="mt-5 text-lg font-semibold tracking-tight text-stitch-text-primary">
                      {module.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-stitch-text-secondary line-clamp-3">
                      {module.description}
                    </p>

                    <div className="mt-5 flex items-center justify-between text-xs text-stitch-text-muted">
                      <span className="inline-flex items-center gap-1.5">
                        <Clock className="h-3.5 w-3.5" />
                        {module.estimatedHours}h
                      </span>
                      <span className="inline-flex items-center gap-1.5 text-stitch-cyan group-hover:translate-x-1 transition-transform">
                        Explore
                        <ArrowRight className="h-3.5 w-3.5" />
                      </span>
                    </div>
                  </div>
                </Link>
              </motion.div>
            )
          })}
        </div>
      </section>

      {/* Intelligence Widget — God Node */}
      <section className="relative mx-auto max-w-7xl px-6 pb-28">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-100px' }}
          transition={{ duration: 0.6 }}
          className="glass-lg relative overflow-hidden rounded-3xl p-8 backdrop-blur-2xl lg:p-12"
        >
          <div className="pointer-events-none absolute -top-24 -right-24 h-64 w-64 rounded-full bg-stitch-cyan/20 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-24 -left-24 h-64 w-64 rounded-full bg-stitch-pink/20 blur-3xl" />

          <div className="relative grid gap-10 lg:grid-cols-2 lg:items-center">
            <div>
              <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-stitch-cyan/30 bg-stitch-cyan/10 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-stitch-cyan">
                <Zap className="h-3 w-3" />
                Intelligence Widget
              </div>
              <h3 className="text-3xl font-bold tracking-tight sm:text-4xl text-stitch-text-primary">
                God Node execution flow
              </h3>
              <p className="mt-4 max-w-md text-stitch-text-secondary">
                Trace your application's call graph with live context. The navigator surfaces the critical path — from entry point to every downstream dependency across 762 system files.
              </p>
            </div>

            <div className="relative">
              <div className="glass rounded-2xl bg-black/30 p-6 font-mono text-sm backdrop-blur-xl">
                <div className="mb-4 flex items-center justify-between text-[11px] uppercase tracking-wider text-stitch-text-muted">
                  <span>call-graph.trace</span>
                  <span className="inline-flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-stitch-green" />
                    live
                  </span>
                </div>

                <div className="space-y-3">
                  <div className="flex items-center gap-3 rounded-lg border border-stitch-cyan/20 bg-stitch-cyan/5 p-3">
                    <span className="h-2.5 w-2.5 flex-shrink-0 rounded-full bg-stitch-cyan shadow-glow-primary" />
                    <span className="text-stitch-cyan">main()</span>
                    <span className="ml-auto text-[11px] text-stitch-text-muted">entry</span>
                  </div>

                  <div className="ml-[14px] h-4 w-px bg-gradient-to-b from-stitch-cyan/50 to-stitch-green/50" />

                  <div className="ml-6 flex items-center gap-3 rounded-lg border border-stitch-green/20 bg-stitch-green/5 p-3">
                    <span className="h-2.5 w-2.5 flex-shrink-0 rounded-full bg-stitch-green shadow-glow-secondary" />
                    <span className="text-stitch-green">get_conn()</span>
                    <span className="ml-auto text-[11px] text-stitch-text-muted">pool</span>
                  </div>

                  <div className="ml-[38px] h-4 w-px bg-gradient-to-b from-stitch-green/50 to-stitch-pink/50" />

                  <div className="ml-12 flex items-center gap-3 rounded-lg border border-stitch-pink/20 bg-stitch-pink/5 p-3">
                    <span className="h-2.5 w-2.5 flex-shrink-0 rounded-full bg-stitch-pink shadow-glow-tertiary" />
                    <span className="text-stitch-pink">run_migrations()</span>
                    <span className="ml-auto text-[11px] text-stitch-text-muted">schema</span>
                  </div>
                </div>

                <div className="mt-5 flex items-center justify-between border-t border-stitch-cyan/20 pt-4 text-[11px] text-stitch-text-muted">
                  <span>3 nodes traced</span>
                  <span>12ms</span>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </section>
    </div>
  )
}

export default HomePage
