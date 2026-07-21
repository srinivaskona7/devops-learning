import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { ArrowRight, Play, Terminal, Compass, Brain, Zap, CheckCircle2, Globe } from 'lucide-react'
import { MODULES } from '../data/modules'
import { useProgress } from '../hooks/useProgress'
import Roadmap from '../components/Roadmap'

const stats = [
  { label: 'Modules', value: '15' },
  { label: 'Projects', value: '10' },
  { label: 'Hours', value: '120+' },
  { label: 'Levels', value: '4' },
]

const stages = [
  { icon: Compass, name: 'Reason', text: 'Why it exists — the real production problem it solves.' },
  { icon: Brain, name: 'Thinking', text: 'A mental model and a diagram before any command.' },
  { icon: Zap, name: 'Execution', text: 'Real commands you run, with a live terminal.' },
  { icon: CheckCircle2, name: 'Output', text: 'What success looks like, verified.' },
  { icon: Globe, name: 'Use-case', text: 'How Netflix, Stripe & Cloudflare do it in prod.' },
]

export default function HomePage() {
  const { completedCount, last } = useProgress()
  const firstModule = MODULES[0]
  const resume = last ? MODULES.find((m) => m.slug === last && m.status === 'available') : null

  return (
    <div>
      {/* ---------------- Hero ---------------- */}
      <section className="relative mx-auto max-w-6xl px-6 pt-20 pb-10 lg:pt-28">
        <div className="stagger">
          <div className="inline-flex items-center gap-2 rounded-full border border-stitch-text-muted/20 bg-white/[0.03] px-3.5 py-1.5 text-xs text-stitch-text-secondary backdrop-blur">
            <Terminal className="h-3.5 w-3.5 text-stitch-cyan" />
            <span className="font-mono tracking-wide">learn by doing · shaped for production</span>
          </div>

          <h1 className="mt-6 max-w-4xl">
            Become the engineer who
            <span className="font-serif-accent text-gradient"> ships with confidence</span>.
          </h1>

          <p className="mt-6 max-w-2xl text-lg text-stitch-text-secondary">
            A hands-on DevOps curriculum taught like the best teacher would: reason first, a
            mental model, then real commands. 15 modules, 10 production projects, one clear path.
          </p>

          <div className="mt-9 flex flex-col items-start gap-4 sm:flex-row sm:items-center">
            <Link to={`/modules/${(resume ?? firstModule).slug}`} className="btn-primary">
              <Play className="h-4 w-4" />
              {resume ? `Resume · ${resume.title}` : 'Start learning'}
              <ArrowRight className="h-4 w-4" />
            </Link>
            <a href="#roadmap" className="btn-secondary">View the roadmap</a>
            {completedCount > 0 && (
              <span className="text-sm text-stitch-text-muted">
                <span className="font-mono text-stitch-cyan">{completedCount}</span> completed
              </span>
            )}
          </div>

          <dl className="mt-14 grid max-w-2xl grid-cols-4 gap-4">
            {stats.map((s) => (
              <div key={s.label} className="glass-sm px-4 py-4">
                <dt className="font-display text-2xl text-stitch-text-primary sm:text-3xl">{s.value}</dt>
                <dd className="mt-0.5 font-mono text-[0.68rem] uppercase tracking-[0.14em] text-stitch-text-muted">{s.label}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      {/* ---------------- Roadmap ---------------- */}
      <section id="roadmap" className="mx-auto max-w-6xl scroll-mt-24 px-6 py-16">
        <div className="mb-8 flex items-end justify-between gap-4">
          <div>
            <div className="rm-track-label mb-2">The path</div>
            <h2>Your DevOps roadmap</h2>
            <p className="mt-2 max-w-xl text-stitch-text-secondary">
              Follow the tracks top to bottom. Each node is a module — tap to open the lesson,
              and it marks done as you go.
            </p>
          </div>
          <Link to="/modules" className="hidden shrink-0 items-center gap-1.5 text-sm font-medium text-stitch-cyan hover:text-stitch-green sm:inline-flex">
            All modules <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
        <Roadmap />
      </section>

      {/* ---------------- How it teaches ---------------- */}
      <section className="mx-auto max-w-6xl px-6 pb-24">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-100px' }}
          transition={{ duration: 0.55 }}
          className="glass-lg overflow-hidden p-8 lg:p-12"
        >
          <div className="rm-track-label mb-2">How every concept is taught</div>
          <h2 className="max-w-2xl">Not slides. A teacher's six-stage flow.</h2>
          <p className="mt-3 max-w-2xl text-stitch-text-secondary">
            The same rhythm on every topic, so learning compounds instead of scattering.
          </p>

          <ol className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
            {stages.map((s, i) => {
              const Icon = s.icon
              return (
                <li key={s.name} className="glass-sm relative p-4">
                  <span className="font-mono text-[0.7rem] text-stitch-text-muted">0{i + 1}</span>
                  <Icon className="mt-2 h-5 w-5 text-stitch-cyan" />
                  <h4 className="mt-2 font-display text-base text-stitch-text-primary">{s.name}</h4>
                  <p className="mt-1 text-[0.82rem] leading-relaxed text-stitch-text-muted">{s.text}</p>
                </li>
              )
            })}
          </ol>
        </motion.div>
      </section>
    </div>
  )
}
