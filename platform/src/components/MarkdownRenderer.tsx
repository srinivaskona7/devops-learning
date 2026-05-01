import React, { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import 'highlight.js/styles/atom-one-dark.css'

interface MarkdownRendererProps {
  filePath: string
  moduleName: string
}

export const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({ filePath, moduleName }) => {
  const [content, setContent] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchMarkdown = async () => {
      try {
        setLoading(true)
        setError(null)

        // Fetch from the public module path
        const response = await fetch(`/${moduleName}/${filePath}`)

        if (!response.ok) {
          throw new Error(`Failed to load ${filePath}`)
        }

        const text = await response.text()
        setContent(text)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error')
        setContent('')
      } finally {
        setLoading(false)
      }
    }

    fetchMarkdown()
  }, [filePath, moduleName])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="text-stitch-text-secondary animate-pulse">Loading module...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="glass p-6 rounded-lg border border-pink-500/30">
        <p className="text-stitch-pink">Error: {error}</p>
      </div>
    )
  }

  return (
    <div className="prose prose-invert max-w-none">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          code: ({ children, ...props }: any) => {
            const isInline = !props.className
            if (isInline) {
              return (
                <code
                  className="px-1.5 py-0.5 rounded bg-stitch-cyan/10 text-stitch-cyan text-sm"
                >
                  {children}
                </code>
              )
            }

            return (
              <pre className="glass p-4 rounded-lg overflow-x-auto mb-4">
                <code className="text-sm text-stitch-text-primary">
                  {children}
                </code>
              </pre>
            )
          },
          h1: (props: any) => (
            <h1 className="text-4xl font-bold text-gradient my-6" {...props} />
          ),
          h2: (props: any) => (
            <h2 className="text-2xl font-bold text-stitch-cyan my-4 mt-8" {...props} />
          ),
          h3: (props: any) => (
            <h3 className="text-xl font-bold text-stitch-green my-3" {...props} />
          ),
          p: (props: any) => (
            <p className="text-stitch-text-secondary my-3 leading-relaxed" {...props} />
          ),
          ul: (props: any) => (
            <ul className="list-disc list-inside space-y-2 my-4 text-stitch-text-secondary" {...props} />
          ),
          ol: (props: any) => (
            <ol className="list-decimal list-inside space-y-2 my-4 text-stitch-text-secondary" {...props} />
          ),
          li: (props: any) => <li className="ml-2" {...props} />,
          blockquote: (props: any) => (
            <blockquote
              className="glass-sm border-l-4 border-stitch-cyan pl-4 py-2 my-4 italic text-stitch-text-muted"
              {...props}
            />
          ),
          a: (props: any) => (
            <a className="text-stitch-cyan hover:text-stitch-green underline" {...props} />
          ),
          table: (props: any) => (
            <table className="w-full border-collapse border border-stitch-cyan/30 my-4" {...props} />
          ),
          th: (props: any) => (
            <th className="border border-stitch-cyan/30 px-3 py-2 bg-stitch-cyan/10 text-stitch-cyan font-bold" {...props} />
          ),
          td: (props: any) => (
            <td className="border border-stitch-cyan/30 px-3 py-2 text-stitch-text-secondary" {...props} />
          ),
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  )
}

