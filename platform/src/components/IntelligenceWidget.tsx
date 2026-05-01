import React from 'react'
import { ArrowDown } from 'lucide-react'

interface GodNode {
  name: string
  description: string
  color: 'cyan' | 'green' | 'pink'
}

const godNodes: GodNode[] = [
  {
    name: 'main()',
    description: 'Entry point',
    color: 'cyan'
  },
  {
    name: 'get_conn()',
    description: 'Database connection',
    color: 'green'
  },
  {
    name: 'run_migrations()',
    description: 'Schema bootstrap',
    color: 'pink'
  }
]

const colorClasses = {
  cyan: 'border-stitch-cyan/40 bg-stitch-cyan/10',
  green: 'border-stitch-green/40 bg-stitch-green/10',
  pink: 'border-stitch-pink/40 bg-stitch-pink/10'
}

const dotClasses = {
  cyan: 'bg-stitch-cyan animate-pulse',
  green: 'bg-stitch-green',
  pink: 'bg-stitch-pink'
}

export const IntelligenceWidget: React.FC = () => {
  return (
    <div className="glass-lg p-6 rounded-xl flex flex-col justify-center">
      <h3 className="text-sm font-bold text-stitch-cyan mb-6 uppercase tracking-wide">
        System Architecture
      </h3>

      <div className="space-y-4">
        {godNodes.map((node, idx) => (
          <div key={node.name}>
            <div className={`flex items-center gap-3 p-3 rounded-lg border ${colorClasses[node.color]}`}>
              <div className={`w-2 h-2 rounded-full ${dotClasses[node.color]}`}></div>
              <div className="flex-1">
                <div className="font-semibold text-sm text-stitch-text-primary">
                  {node.name}
                </div>
                <div className="text-xs text-stitch-text-muted">
                  {node.description}
                </div>
              </div>
            </div>

            {idx < godNodes.length - 1 && (
              <div className="flex justify-center py-2">
                <ArrowDown className="w-4 h-4 text-stitch-cyan/50" />
              </div>
            )}
          </div>
        ))}
      </div>

      <div className="mt-6 pt-4 border-t border-stitch-cyan/20">
        <p className="text-xs text-stitch-text-muted text-center">
          762 system files analyzed via Graphify
        </p>
      </div>
    </div>
  )
}
