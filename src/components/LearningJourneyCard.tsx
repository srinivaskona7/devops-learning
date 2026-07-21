import React from 'react'
import { LucideIcon } from 'lucide-react'

interface LearningJourneyCardProps {
  title: string
  progress: number
  icon: LucideIcon
}

export const LearningJourneyCard: React.FC<LearningJourneyCardProps> = ({
  title,
  progress,
  icon: Icon
}) => {
  return (
    <div className="glass rounded-xl p-6 cursor-pointer hover:shadow-glow-primary hover:translate-y-[-4px] transition-all duration-300">
      <div className="flex items-start justify-between mb-4">
        <div className="w-12 h-12 rounded-lg glass-sm flex items-center justify-center">
          <Icon className="w-6 h-6 text-stitch-cyan" />
        </div>
        <span className="text-xs font-bold text-stitch-green bg-stitch-green/10 px-2 py-1 rounded">
          {progress}%
        </span>
      </div>

      <h3 className="text-base font-bold mb-3 text-stitch-text-primary">{title}</h3>

      {/* Progress Bar */}
      <div className="w-full h-2 bg-stitch-surface rounded-full overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-stitch-cyan to-stitch-green transition-all duration-500"
          style={{ width: `${progress}%` }}
        ></div>
      </div>

      <p className="text-xs text-stitch-text-muted mt-3">
        {progress === 100 ? '✓ Completed' : `${100 - progress}% remaining`}
      </p>
    </div>
  )
}
