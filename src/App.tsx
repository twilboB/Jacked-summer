import { useEffect, useMemo, useState } from 'react'
import type { SetEntry, Workout } from './types'
import { loadGoal, loadWorkouts, saveGoal, saveWorkouts } from './storage'
import {
  daysUntil,
  totalVolume,
  weeklyStreak,
  workoutsThisWeek,
} from './stats'

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

function today(): string {
  return new Date().toISOString().slice(0, 10)
}

const COMMON_LIFTS = [
  'Bench Press',
  'Squat',
  'Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Pull-up',
  'Bicep Curl',
]

export default function App() {
  const [workouts, setWorkouts] = useState<Workout[]>(() => loadWorkouts())
  const [goal, setGoal] = useState(() => loadGoal())

  useEffect(() => saveWorkouts(workouts), [workouts])
  useEffect(() => saveGoal(goal), [goal])

  const streak = useMemo(() => weeklyStreak(workouts), [workouts])
  const thisWeek = useMemo(() => workoutsThisWeek(workouts), [workouts])
  const countdown = useMemo(() => daysUntil(goal.targetDate), [goal.targetDate])
  const totalLifted = useMemo(
    () => workouts.reduce((sum, w) => sum + totalVolume(w), 0),
    [workouts],
  )

  const progress = Math.min(1, thisWeek / goal.weeklyTarget)

  function addWorkout(w: Workout) {
    setWorkouts((prev) =>
      [...prev, w].sort((a, b) => (a.date < b.date ? 1 : -1)),
    )
  }

  function deleteWorkout(id: string) {
    setWorkouts((prev) => prev.filter((w) => w.id !== id))
  }

  return (
    <div className="app">
      <header className="hero">
        <div className="hero-inner">
          <h1>
            <span className="flex">💪</span> Jacked Summer
          </h1>
          <p className="tagline">Put in the reps. Earn the summer.</p>
        </div>
      </header>

      <main className="container">
        <section className="stats">
          <StatCard label="Days to summer" value={countdown} accent="sun" />
          <StatCard label="Week streak" value={streak} suffix="🔥" />
          <ProgressCard
            done={thisWeek}
            target={goal.weeklyTarget}
            progress={progress}
          />
          <StatCard
            label="Total volume"
            value={Math.round(totalLifted).toLocaleString()}
            suffix="lb"
          />
        </section>

        <section className="grid">
          <WorkoutForm onAdd={addWorkout} />
          <GoalPanel goal={goal} onChange={setGoal} />
        </section>

        <WorkoutList workouts={workouts} onDelete={deleteWorkout} />
      </main>

      <footer className="footer">
        Built for the grind · data stays in your browser
      </footer>
    </div>
  )
}

function StatCard({
  label,
  value,
  suffix,
  accent,
}: {
  label: string
  value: number | string
  suffix?: string
  accent?: 'sun'
}) {
  return (
    <div className={`card stat-card ${accent ?? ''}`}>
      <div className="stat-value">
        {value}
        {suffix && <span className="stat-suffix"> {suffix}</span>}
      </div>
      <div className="stat-label">{label}</div>
    </div>
  )
}

function ProgressCard({
  done,
  target,
  progress,
}: {
  done: number
  target: number
  progress: number
}) {
  const deg = Math.round(progress * 360)
  return (
    <div className="card stat-card">
      <div
        className="ring"
        style={{
          background: `conic-gradient(var(--sun) ${deg}deg, var(--ring-track) ${deg}deg)`,
        }}
      >
        <div className="ring-inner">
          {done}/{target}
        </div>
      </div>
      <div className="stat-label">This week</div>
    </div>
  )
}

function WorkoutForm({ onAdd }: { onAdd: (w: Workout) => void }) {
  const [exercise, setExercise] = useState('')
  const [date, setDate] = useState(today())
  const [sets, setSets] = useState<SetEntry[]>([{ reps: 8, weight: 45 }])
  const [notes, setNotes] = useState('')

  function updateSet(i: number, patch: Partial<SetEntry>) {
    setSets((prev) => prev.map((s, idx) => (idx === i ? { ...s, ...patch } : s)))
  }

  function submit(e: React.FormEvent) {
    e.preventDefault()
    if (!exercise.trim()) return
    onAdd({
      id: uid(),
      date,
      exercise: exercise.trim(),
      sets: sets.filter((s) => s.reps > 0),
      notes: notes.trim() || undefined,
    })
    setExercise('')
    setSets([{ reps: 8, weight: 45 }])
    setNotes('')
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>Log a lift</h2>

      <label>
        Exercise
        <input
          list="lifts"
          value={exercise}
          onChange={(e) => setExercise(e.target.value)}
          placeholder="Bench Press"
        />
        <datalist id="lifts">
          {COMMON_LIFTS.map((l) => (
            <option key={l} value={l} />
          ))}
        </datalist>
      </label>

      <label>
        Date
        <input
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
        />
      </label>

      <div className="sets">
        <div className="sets-head">
          <span>Set</span>
          <span>Reps</span>
          <span>Weight</span>
          <span />
        </div>
        {sets.map((s, i) => (
          <div className="set-row" key={i}>
            <span className="set-num">{i + 1}</span>
            <input
              type="number"
              min={0}
              value={s.reps}
              onChange={(e) => updateSet(i, { reps: Number(e.target.value) })}
            />
            <input
              type="number"
              min={0}
              step={2.5}
              value={s.weight}
              onChange={(e) => updateSet(i, { weight: Number(e.target.value) })}
            />
            <button
              type="button"
              className="icon-btn"
              aria-label="Remove set"
              onClick={() =>
                setSets((prev) =>
                  prev.length > 1 ? prev.filter((_, idx) => idx !== i) : prev,
                )
              }
            >
              ✕
            </button>
          </div>
        ))}
        <button
          type="button"
          className="ghost-btn"
          onClick={() =>
            setSets((prev) => [...prev, { ...prev[prev.length - 1] }])
          }
        >
          + Add set
        </button>
      </div>

      <label>
        Notes
        <input
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Felt strong 💪"
        />
      </label>

      <button type="submit" className="primary-btn">
        Save lift
      </button>
    </form>
  )
}

function GoalPanel({
  goal,
  onChange,
}: {
  goal: ReturnType<typeof loadGoal>
  onChange: (g: ReturnType<typeof loadGoal>) => void
}) {
  return (
    <div className="card form">
      <h2>Your goal</h2>
      <label>
        Summer target date
        <input
          type="date"
          value={goal.targetDate}
          onChange={(e) => onChange({ ...goal, targetDate: e.target.value })}
        />
      </label>
      <label>
        Workouts per week
        <input
          type="number"
          min={1}
          max={7}
          value={goal.weeklyTarget}
          onChange={(e) =>
            onChange({
              ...goal,
              weeklyTarget: Math.max(1, Number(e.target.value)),
            })
          }
        />
      </label>
      <p className="hint">
        Hit your weekly target to keep the streak alive and fill the ring.
      </p>
    </div>
  )
}

function WorkoutList({
  workouts,
  onDelete,
}: {
  workouts: Workout[]
  onDelete: (id: string) => void
}) {
  if (workouts.length === 0) {
    return (
      <section className="card empty">
        <p>No lifts logged yet. Time to get to work. 🏋️</p>
      </section>
    )
  }

  return (
    <section className="history">
      <h2>History</h2>
      <ul className="log">
        {workouts.map((w) => (
          <li className="card log-item" key={w.id}>
            <div className="log-main">
              <div className="log-title">
                <span className="log-exercise">{w.exercise}</span>
                <span className="log-date">{w.date}</span>
              </div>
              <div className="log-sets">
                {w.sets.map((s, i) => (
                  <span className="pill" key={i}>
                    {s.reps} × {s.weight}
                  </span>
                ))}
                <span className="pill volume">
                  {Math.round(totalVolume(w)).toLocaleString()} lb
                </span>
              </div>
              {w.notes && <p className="log-notes">{w.notes}</p>}
            </div>
            <button
              className="icon-btn"
              aria-label="Delete workout"
              onClick={() => onDelete(w.id)}
            >
              🗑
            </button>
          </li>
        ))}
      </ul>
    </section>
  )
}
