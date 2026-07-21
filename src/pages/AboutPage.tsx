import { motion } from 'framer-motion'
import { Code, Rocket, Users, BookOpen, Github, ExternalLink } from 'lucide-react'
import { Link } from 'react-router-dom'

const pillars = [
  {
    icon: BookOpen,
    title: 'Hands-on Learning',
    description: 'Every concept follows a 6-stage pattern — Reason, Thinking, Execution, Simulation, Output, Use-case — so you build muscle memory, not just notes.',
  },
  {
    icon: Rocket,
    title: 'Production-Ready',
    description: 'Projects ship with Makefiles, k6 smoke tests, QA plans, and resource limits. What you learn mirrors real clusters.',
  },
  {
    icon: Code,
    title: 'Modern Stack',
    description: 'Docker, Kubernetes, Helm, Terraform, Prometheus, OpenTelemetry — curated around the tools teams actually use today.',
  },
  {
    icon: Users,
    title: 'Community-Driven',
    description: 'Every module is open source. Issues, PRs, and discussions shape the roadmap. Your questions become someone else\'s answer.',
  },
]

const techStack = [
  { name: 'React', purpose: 'Component-driven UI' },
  { name: 'Vite', purpose: 'Instant HMR + lean bundles' },
  { name: 'TypeScript', purpose: 'Type-safe contracts' },
  { name: 'Tailwind', purpose: 'Utility-first styling' },
  { name: 'Framer Motion', purpose: 'Declarative animations' },
  { name: 'Lucide Icons', purpose: 'Crisp iconography' },
  { name: 'React Markdown', purpose: 'Rendered content' },
]

const AboutPage: React.FC = () => {
  return (
    <div className="relative min-h-screen bg-stitch-dark text-stitch-text-primary">
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute -top-32 left-1/2 h-[480px] w-[480px] -translate-x-1/2 rounded-full bg-stitch-cyan/20 blur-3xl" />
        <div className="absolute top-1/3 -right-40 h-[380px] w-[380px] rounded-full bg-stitch-pink/10 blur-3xl" />
      </div>

      <main className="mx-auto w-full max-w-6xl px-6 py-16 lg:py-24 relative">
        <motion.section
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <span className="inline-flex items-center gap-2 rounded-full border border-stitch-cyan/30 bg-stitch-cyan/5 px-4 py-1.5 text-xs font-medium uppercase tracking-[0.18em] text-stitch-cyan backdrop-blur">
            <span className="h-1.5 w-1.5 rounded-full bg-stitch-cyan shadow-glow-primary" />
            Platform Manifesto
          </span>
          <h1 className="mt-6 text-5xl font-bold leading-[1.05] tracking-tight md:text-6xl">
            About <span className="text-gradient">DevOps Navigator</span>
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-lg text-stitch-text-secondary md:text-xl">
            A learn-by-doing curriculum for engineers who want to ship, not skim.
          </p>
        </motion.section>

        {/* Mission */}
        <motion.section
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.6 }}
          className="mx-auto mt-16 max-w-3xl"
        >
          <div className="glass-lg p-8 rounded-3xl md:p-10">
            <h2 className="text-xs font-semibold uppercase tracking-[0.22em] text-stitch-cyan mb-4">Our Mission</h2>
            <p className="text-lg leading-relaxed text-stitch-text-secondary md:text-xl">
              DevOps Navigator exists to turn passive reading into durable mastery. Every module, diagram, and simulation is engineered around one belief: you learn infrastructure by <span className="text-stitch-cyan">operating it</span>, not memorizing it. We replace tutorials with production-grade labs so skills transfer — intact — to incidents, migrations, and launches waiting in your day job.
            </p>
          </div>
        </motion.section>

        {/* Pillars */}
        <motion.section
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.6 }}
          className="mt-20"
        >
          <div className="mb-10 text-center">
            <h2 className="text-3xl font-bold tracking-tight md:text-4xl text-stitch-text-primary">Platform Pillars</h2>
            <p className="mt-3 text-stitch-text-secondary">Four principles shaping every module.</p>
          </div>

          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {pillars.map((pillar, i) => {
              const Icon = pillar.icon
              return (
                <motion.article
                  key={pillar.title}
                  initial={{ opacity: 0, y: 24 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.5, delay: i * 0.08 }}
                  whileHover={{ y: -4 }}
                  className="glass group relative overflow-hidden rounded-2xl p-6 backdrop-blur-xl transition-colors hover:border-stitch-cyan/50"
                >
                  <div className="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-stitch-cyan/30 bg-stitch-cyan/10 text-stitch-cyan shadow-glow-primary">
                    <Icon className="h-5 w-5" />
                  </div>
                  <h3 className="mt-5 text-lg font-semibold text-stitch-text-primary">{pillar.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-stitch-text-secondary">{pillar.description}</p>
                </motion.article>
              )
            })}
          </div>
        </motion.section>

        {/* Tech stack */}
        <motion.section
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.25 }}
          transition={{ duration: 0.6 }}
          className="mt-20"
        >
          <div className="mb-10 text-center">
            <h2 className="text-3xl font-bold tracking-tight md:text-4xl text-stitch-text-primary">Built With</h2>
            <p className="mt-3 text-stitch-text-secondary">A lean, modern stack chosen for speed.</p>
          </div>

          <div className="glass-lg rounded-3xl p-6 md:p-8">
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {techStack.map((tech, i) => (
                <motion.li
                  key={tech.name}
                  initial={{ opacity: 0, x: -8 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.4, delay: i * 0.05 }}
                  className="group flex items-center justify-between rounded-xl border border-stitch-cyan/20 bg-stitch-dark/50 px-4 py-3 transition-colors hover:border-stitch-cyan/50 hover:bg-stitch-cyan/5"
                >
                  <div className="flex items-center gap-3">
                    <span className="h-2 w-2 rounded-full bg-stitch-cyan shadow-glow-primary" />
                    <span className="font-mono text-sm font-medium text-stitch-text-primary">{tech.name}</span>
                  </div>
                  <span className="text-xs text-stitch-text-muted group-hover:text-stitch-cyan transition-colors">{tech.purpose}</span>
                </motion.li>
              ))}
            </ul>
          </div>
        </motion.section>

        {/* Contribute */}
        <motion.section
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.6 }}
          className="mt-20"
        >
          <div className="glass-lg relative overflow-hidden rounded-3xl p-8 md:p-12">
            <div className="relative grid gap-8 lg:grid-cols-[1.4fr,1fr] lg:items-center">
              <div>
                <span className="inline-flex items-center gap-2 rounded-full border border-stitch-cyan/30 bg-stitch-cyan/10 px-3 py-1 text-[11px] font-medium uppercase tracking-[0.2em] text-stitch-cyan">
                  Open Source
                </span>
                <h2 className="mt-4 text-3xl font-bold leading-tight tracking-tight md:text-4xl text-stitch-text-primary">
                  Contribute, critique, or just star the repo.
                </h2>
                <p className="mt-3 max-w-xl text-stitch-text-secondary">
                  Found a bug? Missing a module? The project lives on GitHub — every contribution is credited.
                </p>
              </div>

              <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
                <a
                  href="https://github.com/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group inline-flex items-center justify-center gap-2 rounded-xl border border-stitch-cyan/40 bg-stitch-cyan/10 px-5 py-3 text-sm font-medium text-stitch-cyan shadow-glow-primary transition-all hover:-translate-y-0.5"
                >
                  <Github className="h-4 w-4" />
                  View on GitHub
                  <ExternalLink className="h-3.5 w-3.5 opacity-70 transition-transform group-hover:translate-x-0.5" />
                </a>
                <Link
                  to="/modules"
                  className="inline-flex items-center justify-center gap-2 rounded-xl border border-stitch-cyan/20 bg-stitch-surface px-5 py-3 text-sm font-medium text-stitch-text-primary transition-colors hover:border-stitch-cyan/40"
                >
                  Start Learning →
                </Link>
              </div>
            </div>
          </div>
        </motion.section>
      </main>
    </div>
  )
}

export default AboutPage
