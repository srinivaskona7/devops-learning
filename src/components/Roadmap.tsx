import type { CSSProperties } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Check, Lock, ArrowRight, FileText } from 'lucide-react'
import { MODULES, type Module, type Difficulty } from '../data/modules'
import { useProgress } from '../hooks/useProgress'

/** Curriculum flow — ordered tracks the roadmap renders as rows. */
const TRACKS: { label: string; slugs: string[] }[] = [
  { label: 'Foundations', slugs: ['01-linux', '02-docker'] },
  { label: 'Orchestration', slugs: ['03-kubernetes', '04-helm'] },
  { label: 'Operate', slugs: ['05-monitoring', '06-security'] },
  { label: 'Infrastructure', slugs: ['07-terraform', '11-devops-tools', '10-scripting'] },
  { label: 'Build tooling', slugs: ['12-golang', '13-operators', '14-policy-as-code'] },
  { label: 'Mastery', slugs: ['08-projects', '09-interview-prep', '15-ai-for-devops'] },
]

const LEVEL_ACCENT: Record<Difficulty, string> = {
  beginner: 'var(--level-beginner)',
  intermediate: 'var(--level-intermediate)',
  advanced: 'var(--level-advanced)',
  expert: 'var(--level-expert)',
}

const DOCS_BASE = `${import.meta.env.BASE_URL || '/'}docs/`

function Node({ module }: { module: Module }) {
  const { isDone } = useProgress()
  const Icon = module.icon
  const available = module.status === 'available'
  const done = isDone(module.slug)
  const accent = LEVEL_ACCENT[module.difficulty]

  const inner = (
    <div
      className="rm-node group"
      data-status={done ? 'done' : 'todo'}
      data-locked={!available}
      style={{ '--node-accent': accent } as CSSProperties}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="flex items-center gap-2">
          <span
            className="flex h-8 w-8 items-center justify-center rounded-lg"
            style={{ background: `color-mix(in oklab, ${accent} 16%, transparent)` }}
          >
            <Icon className="h-4 w-4" style={{ color: accent }} strokeWidth={2.2} />
          </span>
          <span className="rm-badge" style={{ '--node-accent': accent } as CSSProperties}>
            {module.difficulty}
          </span>
        </span>
        {done ? (
          <span className="flex h-5 w-5 items-center justify-center rounded-full" style={{ background: 'var(--level-beginner)' }} aria-label="Completed">
            <Check className="h-3 w-3 text-slate-900" strokeWidth={3} />
          </span>
        ) : !available ? (
          <FileText className="h-4 w-4 text-stitch-text-muted" aria-hidden />
        ) : null}
      </div>

      <h4 className="mt-1 font-display text-[0.98rem] leading-snug text-stitch-text-primary">
        {String(module.id).padStart(2, '0')} · {module.title}
      </h4>

      <div className="flex items-center justify-between text-xs text-stitch-text-muted">
        <span>{module.estimatedHours}h</span>
        <span className="inline-flex items-center gap-1 transition-transform group-hover:translate-x-0.5" style={{ color: accent }}>
          {available ? 'Learn' : 'Docs'}
          <ArrowRight className="h-3 w-3" />
        </span>
      </div>
    </div>
  )

  return available ? (
    <Link to={`/modules/${module.slug}`} className="block focus:outline-none">{inner}</Link>
  ) : (
    <a href={`${DOCS_BASE}${module.slug}/`} className="block focus:outline-none">{inner}</a>
  )
}

export default function Roadmap() {
  const bySlug = new Map(MODULES.map((m) => [m.slug, m]))

  return (
    <div className="space-y-5">
      {TRACKS.map((track, ti) => {
        const mods = track.slugs.map((s) => bySlug.get(s)).filter(Boolean) as Module[]
        if (!mods.length) return null
        return (
          <motion.div
            key={track.label}
            initial={{ opacity: 0, y: 18 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.5, delay: ti * 0.04, ease: [0.16, 1, 0.3, 1] }}
            className="grid gap-3 md:grid-cols-[9rem_1fr] md:items-center"
          >
            <div className="flex items-center gap-3 md:flex-col md:items-start md:gap-1">
              <span className="rm-track-label">{String(ti + 1).padStart(2, '0')}</span>
              <span className="rm-track-label !tracking-normal !text-[0.8rem] !normal-case font-display text-stitch-text-secondary">
                {track.label}
              </span>
            </div>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {mods.map((m) => (
                <Node key={m.slug} module={m} />
              ))}
            </div>
          </motion.div>
        )
      })}

      <div className="flex flex-wrap items-center gap-4 pt-2 text-xs text-stitch-text-muted">
        <span className="inline-flex items-center gap-1.5"><Check className="h-3.5 w-3.5" style={{ color: 'var(--level-beginner)' }} /> completed</span>
        <span className="inline-flex items-center gap-1.5"><Lock className="h-3.5 w-3.5" /> docs-only for now</span>
        <span className="ml-auto">Progress saves to this browser.</span>
      </div>
    </div>
  )
}
