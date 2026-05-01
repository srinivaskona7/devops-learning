import React, { useState } from 'react'
import { ChevronDown, BookOpen } from 'lucide-react'

interface Module {
  id: number
  name: string
  title: string
}

const MODULES: Module[] = [
  { id: 1, name: '01-linux', title: 'Linux Fundamentals' },
  { id: 2, name: '02-docker', title: 'Docker & Containers' },
  { id: 3, name: '03-kubernetes', title: 'Kubernetes Core' },
  { id: 4, name: '04-helm', title: 'Helm Charts' },
  { id: 5, name: '05-monitoring', title: 'Monitoring & Observability' },
  { id: 6, name: '06-security', title: 'Security Best Practices' },
  { id: 7, name: '07-terraform', title: 'Terraform Infrastructure' },
  { id: 8, name: '08-projects', title: 'Real-World Projects' },
  { id: 9, name: '09-interview-prep', title: 'Interview Preparation' },
  { id: 10, name: '10-scripting', title: 'Advanced Scripting' },
  { id: 11, name: '11-devops-tools', title: 'DevOps Tools' },
  { id: 12, name: '12-golang', title: 'Go Language' },
  { id: 13, name: '13-operators', title: 'Kubernetes Operators' },
  { id: 14, name: '14-policy-as-code', title: 'Policy as Code' },
  { id: 15, name: '15-ai-for-devops', title: 'AI for DevOps' },
]

interface SidebarProps {
  onModuleSelect: (moduleName: string) => void
  activeModule?: string
}

export const Sidebar: React.FC<SidebarProps> = ({ onModuleSelect, activeModule }) => {
  const [expandedModules, setExpandedModules] = useState<Set<number>>(new Set([1]))

  const toggleModule = (id: number) => {
    const newExpanded = new Set(expandedModules)
    if (newExpanded.has(id)) {
      newExpanded.delete(id)
    } else {
      newExpanded.add(id)
    }
    setExpandedModules(newExpanded)
  }

  return (
    <aside className="w-64 glass-lg rounded-lg h-[calc(100vh-120px)] overflow-y-auto sticky top-20">
      <nav className="p-4">
        <h2 className="text-sm font-bold text-stitch-cyan mb-4 uppercase tracking-wide flex items-center gap-2">
          <BookOpen className="w-4 h-4" />
          Modules
        </h2>

        <ul className="space-y-2">
          {MODULES.map((module) => (
            <li key={module.id}>
              <button
                onClick={() => toggleModule(module.id)}
                className={`w-full flex items-center justify-between px-3 py-2 rounded-md transition-all text-sm font-medium ${
                  activeModule === module.name
                    ? 'bg-stitch-cyan/20 text-stitch-cyan border border-stitch-cyan/40'
                    : 'text-stitch-text-secondary hover:bg-stitch-cyan/10 border border-transparent'
                }`}
              >
                <span className="truncate">{module.title}</span>
                <ChevronDown
                  className={`w-4 h-4 flex-shrink-0 transition-transform ${
                    expandedModules.has(module.id) ? 'rotate-180' : ''
                  }`}
                />
              </button>

              {/* Expanded module content */}
              {expandedModules.has(module.id) && (
                <div className="ml-2 mt-2 pl-2 border-l border-stitch-cyan/30 space-y-1">
                  <button
                    onClick={() => onModuleSelect(module.name)}
                    className={`w-full text-left px-3 py-1 text-xs rounded transition-all ${
                      activeModule === module.name
                        ? 'bg-stitch-green/20 text-stitch-green'
                        : 'text-stitch-text-muted hover:text-stitch-text-secondary'
                    }`}
                  >
                    Overview
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      </nav>
    </aside>
  )
}
