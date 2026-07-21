import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeRaw from 'rehype-raw'
import { motion } from 'framer-motion'
import { MODULES, type Difficulty } from '../data/modules'
import { useProgress } from '../hooks/useProgress'
import Mermaid from '../components/Mermaid'
import { normalizeMarkdown } from '../lib/normalizeMarkdown'
import { ChevronLeft, ChevronRight, Home, BookOpen, Clock, Check, List } from 'lucide-react'

type Depth = 'eli10' | 'standard' | 'deep'

const LEVEL_ACCENT: Record<Difficulty, string> = {
  beginner: 'var(--level-beginner)',
  intermediate: 'var(--level-intermediate)',
  advanced: 'var(--level-advanced)',
  expert: 'var(--level-expert)',
}

const slugify = (s: string) =>
  s.toLowerCase().replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-')

export default function ModulePage() {
  const { moduleId } = useParams<{ moduleId: string }>()
  const [content, setContent] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [depth, setDepth] = useState<Depth>('standard')
  const [scrollPct, setScrollPct] = useState(0)

  const { isDone, toggleDone, visit } = useProgress()

  const currentIndex = MODULES.findIndex((m) => m.slug === moduleId)
  const currentModule = currentIndex >= 0 ? MODULES[currentIndex] : null
  const previousModule = currentIndex > 0 ? MODULES[currentIndex - 1] : null
  const nextModule =
    currentIndex >= 0 && currentIndex < MODULES.length - 1 ? MODULES[currentIndex + 1] : null

  // Load content (redirect coming-soon modules to docs)
  useEffect(() => {
    if (!moduleId || !currentModule) {
      setError(moduleId ? `Module "${moduleId}" not found` : 'No module specified')
      setLoading(false)
      return
    }
    if (currentModule.status === 'coming-soon') {
      const base = import.meta.env.BASE_URL || '/'
      window.location.replace(`${base}docs/${currentModule.slug}/`)
      return
    }
    visit(currentModule.slug)
    setLoading(true)
    setError(null)
    const base = import.meta.env.BASE_URL || '/'
    fetch(`${base}content/${moduleId}/README.md`)
      .then((r) => {
        if (!r.ok) throw new Error(`Failed to load module (${r.status})`)
        return r.text()
      })
      .then((text) => setContent(normalizeMarkdown(text)))
      .catch((e) => setError(e instanceof Error ? e.message : 'Failed to load module'))
      .finally(() => setLoading(false))
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [moduleId, currentModule, visit])

  // Reading progress
  useEffect(() => {
    const onScroll = () => {
      const h = document.documentElement
      const max = h.scrollHeight - h.clientHeight
      setScrollPct(max > 0 ? Math.min(100, (h.scrollTop / max) * 100) : 0)
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => window.removeEventListener('scroll', onScroll)
  }, [content])

  // Table of contents from H2 headings
  const toc = useMemo(
    () =>
      Array.from(content.matchAll(/^##\s+(.+)$/gm)).map((m) => {
        const text = m[1].replace(/[#*`]/g, '').trim()
        return { id: slugify(text), text }
      }),
    [content]
  )

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl animate-pulse space-y-5 px-6 py-16">
        <div className="h-4 w-56 rounded bg-white/10" />
        <div className="h-12 w-3/4 rounded bg-white/15" />
        <div className="h-5 w-1/2 rounded bg-white/10" />
        <div className="space-y-3 pt-6">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-4 rounded bg-white/10" style={{ width: `${92 - i * 6}%` }} />
          ))}
        </div>
      </div>
    )
  }

  if (error || !currentModule) {
    return (
      <div className="mx-auto max-w-xl px-6 py-24 text-center">
        <div className="glass p-10">
          <BookOpen className="mx-auto mb-4 text-stitch-pink" size={44} />
          <h2 className="mb-3">Module not available</h2>
          <p className="mb-8 text-stitch-text-secondary">{error || "We couldn't find that module."}</p>
          <Link to="/modules" className="btn-secondary">Browse modules</Link>
        </div>
      </div>
    )
  }

  const done = isDone(currentModule.slug)
  const accent = LEVEL_ACCENT[currentModule.difficulty]

  return (
    <>
      <div className="read-progress" style={{ width: `${scrollPct}%` }} aria-hidden />

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
        className="mx-auto grid max-w-6xl gap-10 px-6 py-10 lg:grid-cols-[1fr_15rem]"
      >
        <div className="min-w-0">
          {/* Breadcrumb */}
          <nav className="mb-7 flex items-center gap-2 text-sm text-stitch-text-muted">
            <Link to="/" className="inline-flex items-center gap-1 hover:text-stitch-cyan"><Home size={13} /> Home</Link>
            <ChevronRight size={13} className="opacity-40" />
            <Link to="/modules" className="hover:text-stitch-cyan">Modules</Link>
            <ChevronRight size={13} className="opacity-40" />
            <span className="truncate text-stitch-text-secondary">{currentModule.title}</span>
          </nav>

          {/* Header */}
          <header className="mb-8">
            <div className="mb-3 flex flex-wrap items-center gap-2.5">
              <span
                className="rounded-full border px-2.5 py-0.5 font-mono text-[0.65rem] font-semibold uppercase tracking-wider"
                style={{ color: accent, borderColor: `color-mix(in oklab, ${accent} 40%, transparent)`, background: `color-mix(in oklab, ${accent} 12%, transparent)` }}
              >
                {currentModule.difficulty}
              </span>
              <span className="inline-flex items-center gap-1.5 text-xs text-stitch-text-muted">
                <Clock className="h-3.5 w-3.5" /> {currentModule.estimatedHours} hours
              </span>
            </div>
            <h1 className="text-gradient">{currentModule.title}</h1>
            <p className="mt-4 max-w-2xl text-lg text-stitch-text-secondary">{currentModule.description}</p>

            {/* Controls */}
            <div className="mt-6 flex flex-wrap items-center gap-3">
              <div className="diff-toggle" role="group" aria-label="Explanation depth">
                {(['eli10', 'standard', 'deep'] as Depth[]).map((d) => (
                  <button key={d} aria-pressed={depth === d} onClick={() => setDepth(d)}>
                    {d === 'eli10' ? 'ELI10' : d === 'standard' ? 'Standard' : 'Deep dive'}
                  </button>
                ))}
              </div>
              <button
                onClick={() => toggleDone(currentModule.slug)}
                className={done ? 'btn-primary' : 'btn-secondary'}
                aria-pressed={done}
              >
                <Check className="h-4 w-4" />
                {done ? 'Completed' : 'Mark complete'}
              </button>
            </div>
          </header>

          {/* Lesson body */}
          <article className="prose" data-depth={depth}>
            <ReactMarkdown
              remarkPlugins={[remarkGfm]}
              rehypePlugins={[rehypeRaw]}
              components={{
                h2: ({ children, ...props }: any) => (
                  <h2 id={slugify(String(children))} {...props}>{children}</h2>
                ),
                pre: ({ children }: any) => {
                  const child = Array.isArray(children) ? children[0] : children
                  const cls: string = child?.props?.className || ''
                  if (cls.includes('language-mermaid')) {
                    const raw = child?.props?.children
                    const code = Array.isArray(raw) ? raw.join('') : String(raw ?? '')
                    return <Mermaid chart={code.trim()} />
                  }
                  return <pre>{children}</pre>
                },
                a: (props: any) => (
                  <a
                    {...props}
                    target={props.href?.startsWith('http') ? '_blank' : undefined}
                    rel={props.href?.startsWith('http') ? 'noopener noreferrer' : undefined}
                  />
                ),
              }}
            >
              {content}
            </ReactMarkdown>
          </article>

          {/* Prev / Next */}
          <nav className="mt-14 grid grid-cols-1 gap-4 border-t border-stitch-text-muted/10 pt-8 sm:grid-cols-2">
            {previousModule ? (
              <Link to={`/modules/${previousModule.slug}`} className="card card-interactive group flex items-center gap-4">
                <ChevronLeft className="h-5 w-5 flex-shrink-0 text-stitch-cyan transition-transform group-hover:-translate-x-1" />
                <span className="min-w-0">
                  <span className="block font-mono text-[0.65rem] uppercase tracking-wider text-stitch-text-muted">Previous</span>
                  <span className="block truncate font-display font-semibold text-stitch-text-primary">{previousModule.title}</span>
                </span>
              </Link>
            ) : <div />}
            {nextModule ? (
              <Link to={`/modules/${nextModule.slug}`} className="card card-interactive group flex items-center justify-end gap-4 text-right">
                <span className="min-w-0">
                  <span className="block font-mono text-[0.65rem] uppercase tracking-wider text-stitch-text-muted">Next</span>
                  <span className="block truncate font-display font-semibold text-stitch-text-primary">{nextModule.title}</span>
                </span>
                <ChevronRight className="h-5 w-5 flex-shrink-0 text-stitch-cyan transition-transform group-hover:translate-x-1" />
              </Link>
            ) : <div />}
          </nav>
        </div>

        {/* Right rail — TOC + progress */}
        <aside className="hidden lg:block">
          <div className="sticky top-24 space-y-4">
            {toc.length > 0 && (
              <nav className="glass-sm p-4">
                <div className="mb-3 flex items-center gap-2 font-mono text-[0.68rem] uppercase tracking-[0.14em] text-stitch-text-muted">
                  <List className="h-3.5 w-3.5" /> On this page
                </div>
                <ul className="space-y-2 text-sm">
                  {toc.map((h) => (
                    <li key={h.id}>
                      <a href={`#${h.id}`} className="block truncate text-stitch-text-secondary hover:text-stitch-cyan">{h.text}</a>
                    </li>
                  ))}
                </ul>
              </nav>
            )}
            <div className="glass-sm p-4 text-sm">
              <div className="mb-1 font-mono text-[0.68rem] uppercase tracking-[0.14em] text-stitch-text-muted">Reading</div>
              <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
                <div className="h-full rounded-full bg-stitch-cyan transition-[width] duration-150" style={{ width: `${scrollPct}%` }} />
              </div>
              <div className="mt-1 text-right font-mono text-[0.7rem] text-stitch-text-muted">{Math.round(scrollPct)}%</div>
            </div>
          </div>
        </aside>
      </motion.div>
    </>
  )
}
