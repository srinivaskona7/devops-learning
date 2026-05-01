import React from 'react'
import { ChevronRight, Home } from 'lucide-react'

interface BreadcrumbItem {
  label: string
  onClick?: () => void
}

interface ModulePathProps {
  items: BreadcrumbItem[]
  onHomeClick: () => void
}

export const ModulePath: React.FC<ModulePathProps> = ({ items, onHomeClick }) => {
  return (
    <nav className="flex items-center gap-2 text-sm text-stitch-text-secondary mb-6">
      <button
        onClick={onHomeClick}
        className="flex items-center gap-1 text-stitch-cyan hover:text-stitch-green transition"
      >
        <Home className="w-4 h-4" />
        <span>Home</span>
      </button>

      {items.map((item, idx) => (
        <React.Fragment key={idx}>
          <ChevronRight className="w-4 h-4 text-stitch-cyan/50" />
          <button
            onClick={item.onClick}
            className={`transition ${
              idx === items.length - 1
                ? 'text-stitch-text-primary font-semibold cursor-default'
                : 'text-stitch-cyan hover:text-stitch-green'
            }`}
          >
            {item.label}
          </button>
        </React.Fragment>
      ))}
    </nav>
  )
}
