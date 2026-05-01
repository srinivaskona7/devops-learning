import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { motion } from 'framer-motion'
import { MODULES } from '../data/modules'
import { ChevronLeft, ChevronRight, Home, BookOpen, Clock } from 'lucide-react'

const ModulePage: React.FC = () => {
  const { moduleId } = useParams<{ moduleId: string }>()
  const [content, setContent] = useState<string>('')
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)

  const currentIndex = MODULES.findIndex((m) => m.slug === moduleId)
  const currentModule = currentIndex >= 0 ? MODULES[currentIndex] : null
  const previousModule = currentIndex > 0 ? MODULES[currentIndex - 1] : null
  const nextModule = currentIndex >= 0 && currentIndex < MODULES.length - 1 ? MODULES[currentIndex + 1] : null

  useEffect(() => {
    if (!moduleId || !currentModule) {
      setError(moduleId ? `Module "${moduleId}" not found` : 'No module specified')
      setLoading(false)
      return
    }

    const fetchContent = async () => {
      setLoading(true)
      setError(null)
      try {
        const base = import.meta.env.BASE_URL || '/'
        const response = await fetch(`${base}content/${moduleId}/README.md`)
        if (!response.ok) {
          throw new Error(`Failed to load module (${response.status})`)
        }
        const text = await response.text()
        setContent(text)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load module')
      } finally {
        setLoading(false)
      }
    }

    fetchContent()
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [moduleId, currentModule])

  const difficultyColor = (d?: string) => {
    switch (d) {
      case 'beginner':
        return 'text-stitch-green border-stitch-green/40 bg-stitch-green/10'
      case 'intermediate':
        return 'text-stitch-cyan border-stitch-cyan/40 bg-stitch-cyan/10'
      case 'advanced':
        return 'text-stitch-pink border-stitch-pink/40 bg-stitch-pink/10'
      default:
        return 'text-purple-300 border-purple-400/40 bg-purple-400/10'
    }
  }

  if (loading) {
    return (
      <div className="max-w-5xl mx-auto px-6 py-10">
        <div className="animate-pulse space-y-6">
          <div className="h-4 w-64 rounded bg-stitch-cyan/10" />
          <div className="h-10 w-3/4 rounded bg-stitch-cyan/20" />
          <div className="h-6 w-1/2 rounded bg-stitch-cyan/10" />
          <div className="flex gap-3">
            <div className="h-8 w-24 rounded-full bg-stitch-cyan/10" />
            <div className="h-8 w-24 rounded-full bg-stitch-cyan/10" />
          </div>
          <div className="space-y-3 pt-6">
            <div className="h-4 w-full rounded bg-stitch-cyan/10" />
            <div className="h-4 w-11/12 rounded bg-stitch-cyan/10" />
            <div className="h-4 w-10/12 rounded bg-stitch-cyan/10" />
          </div>
          <div className="h-64 w-full rounded-lg bg-stitch-cyan/5 glass" />
        </div>
      </div>
    )
  }

  if (error || !currentModule) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="max-w-2xl mx-auto px-6 py-20 text-center"
      >
        <div className="glass p-10 rounded-2xl">
          <BookOpen className="mx-auto mb-4 text-stitch-pink" size={48} />
          <h2 className="text-3xl font-bold text-gradient mb-3">Module Not Available</h2>
          <p className="text-stitch-text-secondary mb-8 leading-relaxed">
            {error || "We couldn't find the module. It may have moved."}
          </p>
          <Link
            to="/modules"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-lg bg-stitch-cyan/10 border border-stitch-cyan/40 text-stitch-cyan hover:bg-stitch-cyan/20 transition-colors"
          >
            <BookOpen size={18} />
            Browse modules
          </Link>
        </div>
      </motion.div>
    )
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      className="max-w-5xl mx-auto px-6 py-10"
    >
      {/* Breadcrumb */}
      <nav className="flex items-center gap-2 text-sm text-stitch-text-secondary mb-8">
        <Link to="/" className="inline-flex items-center gap-1 hover:text-stitch-cyan transition-colors">
          <Home size={14} />
          Home
        </Link>
        <ChevronRight size={14} className="opacity-50" />
        <Link to="/modules" className="hover:text-stitch-cyan transition-colors">
          Modules
        </Link>
        <ChevronRight size={14} className="opacity-50" />
        <span className="text-stitch-text-primary truncate">{currentModule.title}</span>
      </nav>

      {/* Header */}
      <header className="mb-10">
        <h1 className="text-4xl md:text-5xl font-bold text-gradient mb-4">{currentModule.title}</h1>
        <p className="text-lg text-stitch-text-secondary leading-relaxed mb-6 max-w-3xl">
          {currentModule.description}
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <span
            className={`px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider border ${difficultyColor(currentModule.difficulty)}`}
          >
            {currentModule.difficulty}
          </span>
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border border-stitch-cyan/30 text-stitch-cyan bg-stitch-cyan/5">
            <Clock className="w-3 h-3" />
            {currentModule.estimatedHours} hours
          </span>
        </div>
      </header>

      {/* Markdown */}
      <article className="glass-lg p-8 rounded-xl">
        <ReactMarkdown
          remarkPlugins={[remarkGfm]}
          components={{
            h1: (props: any) => <h1 className="text-4xl font-bold text-gradient my-6" {...props} />,
            h2: (props: any) => <h2 className="text-2xl font-bold text-stitch-cyan my-4 mt-8" {...props} />,
            h3: (props: any) => <h3 className="text-xl font-bold text-stitch-green my-3" {...props} />,
            p: (props: any) => <p className="text-stitch-text-secondary my-3 leading-relaxed" {...props} />,
            code: ({ children, ...props }: any) => {
              const isInline = !props.className
              if (isInline) {
                return <code className="px-1.5 py-0.5 rounded bg-stitch-cyan/10 text-stitch-cyan text-sm">{children}</code>
              }
              return <code className="text-sm text-stitch-text-primary">{children}</code>
            },
            pre: (props: any) => <pre className="glass p-4 rounded-lg overflow-x-auto mb-4" {...props} />,
            table: (props: any) => (
              <div className="overflow-x-auto my-6">
                <table className="border border-stitch-cyan/30 w-full" {...props} />
              </div>
            ),
            th: (props: any) => <th className="border border-stitch-cyan/30 px-4 py-2 text-left text-stitch-cyan font-semibold bg-stitch-cyan/5" {...props} />,
            td: (props: any) => <td className="border border-stitch-cyan/20 px-4 py-2 text-stitch-text-secondary" {...props} />,
            a: (props: any) => (
              <a
                className="text-stitch-cyan hover:text-stitch-green underline"
                target={props.href?.startsWith('http') ? '_blank' : undefined}
                rel={props.href?.startsWith('http') ? 'noopener noreferrer' : undefined}
                {...props}
              />
            ),
            ul: (props: any) => <ul className="list-disc list-inside my-4 space-y-2 text-stitch-text-secondary ml-4" {...props} />,
            ol: (props: any) => <ol className="list-decimal list-inside my-4 space-y-2 text-stitch-text-secondary ml-4" {...props} />,
            li: (props: any) => <li className="leading-relaxed" {...props} />,
            blockquote: (props: any) => (
              <blockquote
                className="border-l-4 border-stitch-cyan/40 pl-4 my-4 italic text-stitch-text-secondary bg-stitch-cyan/5 py-2"
                {...props}
              />
            ),
            hr: (props: any) => <hr className="border-stitch-cyan/20 my-8" {...props} />,
          }}
        >
          {content}
        </ReactMarkdown>
      </article>

      {/* Prev / Next */}
      <nav className="mt-16 pt-8 border-t border-stitch-cyan/20 grid grid-cols-1 md:grid-cols-2 gap-4">
        {previousModule ? (
          <Link
            to={`/modules/${previousModule.slug}`}
            className="group glass p-5 rounded-xl hover:border-stitch-cyan/60 transition-all flex items-center gap-4"
          >
            <ChevronLeft size={24} className="text-stitch-cyan flex-shrink-0 group-hover:-translate-x-1 transition-transform" />
            <div className="min-w-0">
              <div className="text-xs uppercase tracking-wider text-stitch-text-muted mb-1">Previous</div>
              <div className="font-semibold text-stitch-text-primary truncate group-hover:text-stitch-cyan transition-colors">
                {previousModule.title}
              </div>
            </div>
          </Link>
        ) : <div />}

        {nextModule ? (
          <Link
            to={`/modules/${nextModule.slug}`}
            className="group glass p-5 rounded-xl hover:border-stitch-green/60 transition-all flex items-center justify-end gap-4 text-right"
          >
            <div className="min-w-0">
              <div className="text-xs uppercase tracking-wider text-stitch-text-muted mb-1">Next</div>
              <div className="font-semibold text-stitch-text-primary truncate group-hover:text-stitch-green transition-colors">
                {nextModule.title}
              </div>
            </div>
            <ChevronRight size={24} className="text-stitch-green flex-shrink-0 group-hover:translate-x-1 transition-transform" />
          </Link>
        ) : <div />}
      </nav>
    </motion.div>
  )
}

export default ModulePage
