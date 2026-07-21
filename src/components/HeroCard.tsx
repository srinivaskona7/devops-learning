import React from 'react'
import { Zap } from 'lucide-react'

export const HeroCard: React.FC = () => {
  return (
    <div className="glass p-8 rounded-xl hover:shadow-glow-primary transition-all duration-300 relative overflow-hidden">
      <div className="relative z-10">
        <h2 className="text-4xl font-bold mb-4">
          <span className="text-gradient">The Intelligent DevOps Navigator</span>
        </h2>
        <p className="text-stitch-text-secondary mb-6">
          Master cloud infrastructure through hands-on learning. 15 modules, 10 real-world projects, and a curriculum designed for production excellence.
        </p>
        <button className="px-6 py-3 bg-gradient-to-r from-stitch-cyan to-stitch-green text-stitch-dark font-bold rounded-lg hover:shadow-glow-lg transition-all hover:translate-y-[-2px]">
          Start Learning
        </button>
      </div>

      {/* Animated pulsing cursor */}
      <div className="absolute right-8 top-8 w-12 h-12">
        <div className="absolute inset-0 rounded-full border-2 border-stitch-cyan/30 animate-pulse"></div>
        <div className="absolute inset-2 rounded-full border border-stitch-cyan/60"></div>
        <Zap className="absolute inset-3 w-6 h-6 text-stitch-cyan/50" />
      </div>
    </div>
  )
}
