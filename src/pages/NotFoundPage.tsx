import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Home, AlertTriangle } from 'lucide-react'

const NotFoundPage: React.FC = () => {
  return (
    <div className="relative min-h-[80vh] flex items-center justify-center overflow-hidden bg-stitch-dark">
      {/* Grid background */}
      <div
        className="absolute inset-0 opacity-10 pointer-events-none"
        style={{
          backgroundImage:
            'linear-gradient(rgba(236, 72, 153, 0.15) 1px, transparent 1px), linear-gradient(90deg, rgba(236, 72, 153, 0.15) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
        }}
      />

      {/* Floating particles */}
      <div className="absolute inset-0 pointer-events-none">
        {Array.from({ length: 20 }).map((_, p) => (
          <motion.div
            key={p}
            className="absolute w-1 h-1 rounded-full"
            style={{
              background: p % 3 === 0 ? '#ec4899' : p % 3 === 1 ? '#22d3ee' : '#4ade80',
              boxShadow: `0 0 10px ${p % 3 === 0 ? '#ec4899' : p % 3 === 1 ? '#22d3ee' : '#4ade80'}`,
              left: `${(p * 37) % 100}%`,
              top: `${(p * 53) % 100}%`,
            }}
            animate={{
              y: [0, (p % 2 === 0 ? -1 : 1) * 60, 0],
              opacity: [0.2, 0.8, 0.2],
            }}
            transition={{
              duration: 6 + (p % 4),
              repeat: Infinity,
              ease: 'easeInOut',
              delay: (p % 5) * 0.3,
            }}
          />
        ))}
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 text-center px-6 max-w-2xl"
      >
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-stitch-pink/40 bg-stitch-pink/10 backdrop-blur-md mb-6">
          <AlertTriangle className="w-4 h-4 text-stitch-pink" />
          <span className="text-xs uppercase tracking-[0.2em] font-mono text-stitch-pink">
            Signal lost · Error 404
          </span>
        </div>

        <motion.h1
          className="text-gradient font-black leading-none select-none mb-6"
          style={{ fontSize: 'clamp(6rem, 18vw, 14rem)', letterSpacing: '-0.05em' }}
          animate={{
            textShadow: [
              '0 0 20px rgba(236, 72, 153, 0.6), 0 0 40px rgba(168, 85, 247, 0.4)',
              '0 0 40px rgba(236, 72, 153, 0.9), 0 0 80px rgba(168, 85, 247, 0.6)',
              '0 0 20px rgba(236, 72, 153, 0.6), 0 0 40px rgba(168, 85, 247, 0.4)',
            ],
          }}
          transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' }}
        >
          404
        </motion.h1>

        <p className="text-xl md:text-2xl text-stitch-text-primary/80 mb-3">
          Page not found in this reality
        </p>
        <p className="text-sm font-mono text-stitch-text-muted mb-10">
          &gt; The coordinates you requested have drifted into the void.
        </p>

        <Link
          to="/"
          className="group inline-flex items-center gap-3 px-8 py-4 rounded-xl font-bold text-stitch-dark bg-gradient-to-r from-stitch-cyan via-stitch-green to-stitch-cyan bg-[length:200%_auto] shadow-glow-primary transition-all duration-300 hover:scale-[1.03] hover:shadow-glow-lg animate-pulse-glow"
        >
          <Home className="w-5 h-5" />
          <span className="tracking-wide">Return to Navigator</span>
        </Link>
      </motion.div>
    </div>
  )
}

export default NotFoundPage
