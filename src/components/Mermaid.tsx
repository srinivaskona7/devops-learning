import { useEffect, useRef, useState } from 'react'

let idCounter = 0

/**
 * Renders a Mermaid diagram from a code string. Mermaid is dynamically
 * imported so it only loads on lesson pages that actually contain diagrams.
 */
export default function Mermaid({ chart }: { chart: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [error, setError] = useState(false)
  const [id] = useState(() => `mmd-${++idCounter}`)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const mermaid = (await import('mermaid')).default
        mermaid.initialize({
          startOnLoad: false,
          theme: 'base',
          securityLevel: 'strict',
          fontFamily: '"JetBrains Mono", ui-monospace, monospace',
          themeVariables: {
            background: 'transparent',
            primaryColor: '#0f1c33',
            primaryBorderColor: '#22d3ee',
            primaryTextColor: '#e2f5ff',
            lineColor: '#64748b',
            secondaryColor: '#1e293b',
            tertiaryColor: '#111a2e',
            fontSize: '14px',
          },
        })
        const { svg } = await mermaid.render(id, chart)
        if (!cancelled && ref.current) ref.current.innerHTML = svg
      } catch {
        if (!cancelled) setError(true)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [chart, id])

  if (error) {
    return (
      <pre className="mermaid-fallback">
        <code>{chart}</code>
      </pre>
    )
  }

  return <div className="mermaid-diagram" ref={ref} role="img" aria-label="diagram" />
}
