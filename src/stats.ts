import type { Workout } from './types'

export function totalVolume(workout: Workout): number {
  return workout.sets.reduce((sum, s) => sum + s.reps * s.weight, 0)
}

/** Start of the ISO-ish week (Monday) for a given date, as YYYY-MM-DD. */
export function weekStart(date: Date): string {
  const d = new Date(date)
  const day = (d.getDay() + 6) % 7 // 0 = Monday
  d.setDate(d.getDate() - day)
  return d.toISOString().slice(0, 10)
}

/** Number of distinct days trained in the current week. */
export function workoutsThisWeek(workouts: Workout[], now = new Date()): number {
  const start = weekStart(now)
  const days = new Set(
    workouts.filter((w) => weekStart(new Date(w.date)) === start).map((w) => w.date),
  )
  return days.size
}

/**
 * Consecutive-week streak: how many weeks in a row (ending this week or last)
 * the lifter trained at least once.
 */
export function weeklyStreak(workouts: Workout[], now = new Date()): number {
  if (workouts.length === 0) return 0
  const weeks = new Set(workouts.map((w) => weekStart(new Date(w.date))))
  let streak = 0
  const cursor = new Date(now)
  // Allow the streak to be "alive" even if this week has no workout yet.
  if (!weeks.has(weekStart(cursor))) cursor.setDate(cursor.getDate() - 7)
  while (weeks.has(weekStart(cursor))) {
    streak++
    cursor.setDate(cursor.getDate() - 7)
  }
  return streak
}

export function daysUntil(targetDate: string, now = new Date()): number {
  const target = new Date(targetDate + 'T00:00:00')
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const ms = target.getTime() - today.getTime()
  return Math.max(0, Math.round(ms / 86_400_000))
}
