// packages/shared/src/utils/telemetry.ts
const enabled = String(process.env.ENABLE_TELEMETRY || 'false') === 'true'
export function track(name: string, props?: Record<string, any>) {
  if (!enabled) return
  // Plug your analytics here
}
export function captureError(error: unknown, context?: Record<string, any>) {
  if (!enabled) return
  // Plug your error reporter here
}
