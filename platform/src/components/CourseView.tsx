import React, { useState } from 'react'
import { Sidebar, MarkdownRenderer, ModulePath } from './index'

interface CourseViewProps {
  onBackToHome: () => void
}

export const CourseView: React.FC<CourseViewProps> = ({ onBackToHome }) => {
  const [activeModule, setActiveModule] = useState<string | null>('01-linux')
  const [currentFile, setCurrentFile] = useState<string>('README.md')

  const handleModuleSelect = (moduleName: string) => {
    setActiveModule(moduleName)
    setCurrentFile('README.md')
  }

  const getModuleTitle = (moduleName: string | null): string => {
    if (!moduleName) return 'Modules'

    const moduleMap: { [key: string]: string } = {
      '01-linux': 'Linux Fundamentals',
      '02-docker': 'Docker & Containers',
      '03-kubernetes': 'Kubernetes Core',
      '04-helm': 'Helm Charts',
      '05-monitoring': 'Monitoring & Observability',
      '06-security': 'Security Best Practices',
      '07-terraform': 'Terraform Infrastructure',
      '08-projects': 'Real-World Projects',
      '09-interview-prep': 'Interview Preparation',
      '10-scripting': 'Advanced Scripting',
      '11-devops-tools': 'DevOps Tools',
      '12-golang': 'Go Language',
      '13-operators': 'Kubernetes Operators',
      '14-policy-as-code': 'Policy as Code',
      '15-ai-for-devops': 'AI for DevOps',
    }

    return moduleMap[moduleName] || moduleName
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 p-6">
      {/* Sidebar */}
      <div className="lg:col-span-1">
        <Sidebar onModuleSelect={handleModuleSelect} activeModule={activeModule || ''} />
      </div>

      {/* Main Content */}
      <div className="lg:col-span-3">
        <ModulePath
          items={[{ label: getModuleTitle(activeModule) }]}
          onHomeClick={onBackToHome}
        />

        {activeModule ? (
          <div className="glass-lg p-8 rounded-xl">
            <MarkdownRenderer filePath={currentFile} moduleName={activeModule} />
          </div>
        ) : (
          <div className="glass-lg p-8 rounded-xl text-center">
            <p className="text-stitch-text-secondary">Select a module to begin learning</p>
          </div>
        )}
      </div>
    </div>
  )
}
