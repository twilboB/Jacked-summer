export interface SetEntry {
  reps: number
  weight: number
}

export interface Workout {
  id: string
  date: string // ISO date string (YYYY-MM-DD)
  exercise: string
  sets: SetEntry[]
  notes?: string
}

export interface Goal {
  /** Target date to be "jacked" by — defaults to end of summer. */
  targetDate: string
  /** Weekly workout target used for the streak / progress ring. */
  weeklyTarget: number
}
