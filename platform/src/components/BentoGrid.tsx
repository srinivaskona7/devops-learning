import React from 'react'

interface BentoGridProps {
  children: React.ReactNode
}

export const BentoGrid: React.FC<BentoGridProps> = ({ children }) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {children}
    </div>
  )
}

interface BentoItemProps {
  children: React.ReactNode
  span?: 'full' | 2 | 3
  className?: string
}

export const BentoItem: React.FC<BentoItemProps> = ({
  children,
  span = 1,
  className = ''
}) => {
  const spanClass = span === 'full' ? 'lg:col-span-3' : span === 2 ? 'lg:col-span-2' : ''

  return (
    <div className={`glass rounded-xl p-6 hover:shadow-glow-primary hover:translate-y-[-4px] transition-all duration-300 ${spanClass} ${className}`}>
      {children}
    </div>
  )
}
