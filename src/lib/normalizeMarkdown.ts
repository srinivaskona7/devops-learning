/**
 * Normalizes MkDocs-flavored markdown into renderer-agnostic markdown so it
 * displays cleanly in the SPA. Applied to every lesson at fetch time.
 *
 * Handles the two constructs that break generic markdown renderers:
 *   1. Admonitions:  `!!! type "Title"` + 4-space-indented body  → callout blockquote
 *   2. Orphaned code: bare shell lines after `<span class="stage execution">`
 *      (no code fence, so `# comments` were parsing as headings) → ```bash fence
 */
export function normalizeMarkdown(md: string): string {
  const lines = md.split('\n')
  const out: string[] = []

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // 1. Admonition: !!! type "Title"  (also ??? collapsible)
    const adm = line.match(/^(?:!!!|\?\?\?\+?|!!!\+)\s+([\w-]+)(?:\s+"([^"]*)")?\s*$/)
    if (adm) {
      const kind = adm[1].replace(/-/g, ' ')
      const title = adm[2] || kind.replace(/\b\w/g, (c) => c.toUpperCase())
      const icon = /danger|warning|caution/i.test(adm[1]) ? '⚠️'
        : /note|info|tip|hint/i.test(adm[1]) ? '💡'
        : /example/i.test(adm[1]) ? '🧪' : '📌'
      out.push(`> ${icon} **${title}**`)
      let j = i + 1
      const body: string[] = []
      while (j < lines.length && (/^(\s{4}|\t)/.test(lines[j]) || lines[j].trim() === '')) {
        if (lines[j].trim() === '' && !/^(\s{4}|\t)/.test(lines[j + 1] || '')) break
        body.push(lines[j].replace(/^(\s{4}|\t)/, ''))
        j++
      }
      while (body.length && body[body.length - 1].trim() === '') body.pop()
      for (const b of body) out.push(b.trim() === '' ? '>' : `> ${b}`)
      i = j - 1
      continue
    }

    // 2. Orphaned shell block after an Execution stage label
    const stage = line.match(/^<span class="stage execution">.*<\/span>\s*$/)
    if (stage) {
      out.push(line)
      let j = i + 1
      // skip a single blank line right after the label
      if (lines[j] !== undefined && lines[j].trim() === '') j++
      const code: string[] = []
      while (j < lines.length && !/^\s*(<|!!!|\?\?\?|```)/.test(lines[j])) {
        code.push(lines[j])
        j++
      }
      while (code.length && code[code.length - 1].trim() === '') code.pop()
      if (code.length) {
        out.push('')
        out.push('```bash')
        out.push(...code)
        out.push('```')
      }
      i = j - 1
      continue
    }

    out.push(line)
  }

  return out.join('\n')
}
