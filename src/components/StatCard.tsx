import React from 'react'

interface StatCardProps {
  label: string
  value: string
}

export const StatCard: React.FC<StatCardProps> = ({ label, value }) => {
  return (
    <div className="glass-sm p-6 rounded-lg text-center">
      <div className="text-2xl font-bold text-gradient mb-2">{value}</div>
      <p className="text-xs text-stitch-text-muted uppercase tracking-wide">{label}</p>
    </div>
  )
}
