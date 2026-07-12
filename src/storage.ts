import type { Goal, Workout } from './types'

const WORKOUTS_KEY = 'jacked-summer:workouts'
const GOAL_KEY = 'jacked-summer:goal'

function defaultGoal(): Goal {
  const now = new Date()
  // "End of summer" = Sept 22 of the current (or next) year.
  const year = now.getMonth() > 8 ? now.getFullYear() + 1 : now.getFullYear()
  const target = new Date(year, 8, 22)
  return {
    targetDate: target.toISOString().slice(0, 10),
    weeklyTarget: 4,
  }
}

export function loadWorkouts(): Workout[] {
  try {
    const raw = localStorage.getItem(WORKOUTS_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? (parsed as Workout[]) : []
  } catch {
    return []
  }
}

export function saveWorkouts(workouts: Workout[]): void {
  localStorage.setItem(WORKOUTS_KEY, JSON.stringify(workouts))
}

export function loadGoal(): Goal {
  try {
    const raw = localStorage.getItem(GOAL_KEY)
    if (!raw) return defaultGoal()
    return { ...defaultGoal(), ...(JSON.parse(raw) as Partial<Goal>) }
  } catch {
    return defaultGoal()
  }
}

export function saveGoal(goal: Goal): void {
  localStorage.setItem(GOAL_KEY, JSON.stringify(goal))
}
