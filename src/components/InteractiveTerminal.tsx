import React, { useState, useEffect } from 'react'
import { TerminalSquare, AlertTriangle } from 'lucide-react'

interface SecurityAlert {
  id: string
  timestamp: string
  severity: 'high' | 'medium' | 'low'
  rule: string
  process: string
  container: string
  action: string
}

const FALCO_ALERTS: SecurityAlert[] = [
  {
    id: '1',
    timestamp: '14:32:45.123',
    severity: 'high',
    rule: 'Write below root',
    process: 'bash',
    container: 'production-app-8f4d2',
    action: 'KILLED'
  },
  {
    id: '2',
    timestamp: '14:32:47.456',
    severity: 'medium',
    rule: 'Unauthorized privilege escalation',
    process: 'sudo',
    container: 'web-server-prod-1a',
    action: 'BLOCKED'
  },
  {
    id: '3',
    timestamp: '14:32:49.789',
    severity: 'high',
    rule: 'Suspicious network connection',
    process: 'curl',
    container: 'api-gateway-v2-3c',
    action: 'LOGGED'
  },
  {
    id: '4',
    timestamp: '14:32:51.012',
    severity: 'medium',
    rule: 'Sensitive file access',
    process: 'cat',
    container: 'database-service-5',
    action: 'LOGGED'
  },
  {
    id: '5',
    timestamp: '14:32:53.345',
    severity: 'low',
    rule: 'Shell history access',
    process: 'history',
    container: 'shell-env-prod',
    action: 'MONITORED'
  },
]

const severityColors = {
  high: 'text-stitch-pink',
  medium: 'text-stitch-cyan',
  low: 'text-stitch-green',
}

const severityBg = {
  high: 'bg-stitch-pink/10',
  medium: 'bg-stitch-cyan/10',
  low: 'bg-stitch-green/10',
}

export const InteractiveTerminal: React.FC = () => {
  const [displayedAlerts, setDisplayedAlerts] = useState<SecurityAlert[]>([])

  useEffect(() => {
    // Simulate real-time alerts appearing
    FALCO_ALERTS.forEach((alert, idx) => {
      setTimeout(() => {
        setDisplayedAlerts((prev) => [...prev, alert])
      }, idx * 800)
    })
  }, [])

  useEffect(() => {
    // Auto-scroll to bottom
    const container = document.getElementById('terminal-output')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }, [displayedAlerts])

  return (
    <div className="glass-lg p-6 rounded-xl">
      {/* Terminal Header */}
      <div className="flex items-center justify-between mb-4 pb-4 border-b border-stitch-cyan/30">
        <div className="flex items-center gap-3">
          <TerminalSquare className="w-5 h-5 text-stitch-cyan animate-glow" />
          <h3 className="text-sm font-bold text-stitch-cyan uppercase tracking-wide">
            Security Monitoring (Falco)
          </h3>
        </div>
        <div className="flex gap-2">
          <div className="w-2 h-2 rounded-full bg-stitch-green animate-pulse"></div>
          <span className="text-xs text-stitch-text-muted">Live</span>
        </div>
      </div>

      {/* Terminal Output */}
      <div
        id="terminal-output"
        className="space-y-2 h-96 overflow-y-auto bg-stitch-dark/50 p-4 rounded-lg border border-stitch-cyan/20 font-mono text-xs relative animate-scan-lines"
      >
        {/* Terminal scanlines effect */}
        <div className="absolute inset-0 pointer-events-none bg-repeat opacity-10 mix-blend-overlay"
          style={{
            backgroundImage: 'repeating-linear-gradient(0deg, #000 0px, #000 1px, transparent 1px, transparent 2px)'
          }}
        ></div>

        {displayedAlerts.length === 0 ? (
          <div className="text-stitch-text-muted text-center py-12">
            Waiting for security events...
          </div>
        ) : (
          displayedAlerts.map((alert) => (
            <div
              key={alert.id}
              className={`p-2 rounded border-l-2 ${severityBg[alert.severity]} ${
                alert.severity === 'high'
                  ? 'border-stitch-pink'
                  : alert.severity === 'medium'
                  ? 'border-stitch-cyan'
                  : 'border-stitch-green'
              } animate-fadeIn`}
            >
              <div className="flex items-start gap-2">
                <AlertTriangle className={`w-4 h-4 flex-shrink-0 mt-0.5 ${severityColors[alert.severity]}`} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <span className={`font-bold ${severityColors[alert.severity]}`}>
                      [{alert.severity.toUpperCase()}]
                    </span>
                    <span className="text-stitch-text-muted text-xs">{alert.timestamp}</span>
                  </div>

                  <div className="text-stitch-text-secondary mb-1">
                    <span className="text-stitch-cyan">Rule:</span> {alert.rule}
                  </div>

                  <div className="grid grid-cols-2 gap-2 text-stitch-text-muted text-xs mb-1">
                    <div>
                      <span className="text-stitch-green">Process:</span> {alert.process}
                    </div>
                    <div>
                      <span className="text-stitch-green">Container:</span> {alert.container}
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="text-stitch-text-muted">Action:</span>
                    <span
                      className={`px-2 py-0.5 rounded text-xs font-semibold ${
                        alert.action === 'KILLED'
                          ? 'bg-stitch-pink/20 text-stitch-pink'
                          : alert.action === 'BLOCKED'
                          ? 'bg-stitch-cyan/20 text-stitch-cyan'
                          : 'bg-stitch-green/20 text-stitch-green'
                      }`}
                    >
                      {alert.action}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          ))
        )}

        {displayedAlerts.length > 0 && (
          <div className="text-stitch-text-muted text-center py-2 border-t border-stitch-cyan/20 mt-4">
            {displayedAlerts.length} events | Falco Runtime Security
          </div>
        )}
      </div>

      {/* Terminal Footer */}
      <div className="mt-4 pt-4 border-t border-stitch-cyan/30">
        <div className="text-xs text-stitch-text-muted space-y-1">
          <div>
            <span className="text-stitch-green">$</span> falco -o file_output.sctp:/tmp/falco.sctp
          </div>
          <div>Running Falco with Kubernetes support enabled...</div>
        </div>
      </div>
    </div>
  )
}
