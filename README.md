# 💪 Jacked Summer

Put in the reps. Earn the summer.

A lightweight workout tracker to help you stay consistent on the road to a jacked summer. Log your lifts, keep your weekly streak alive, watch your total volume climb, and count down the days until summer.

## Features

- **Log lifts** — exercise, date, and any number of sets (reps × weight), plus notes.
- **Summer countdown** — days remaining until your target date.
- **Weekly streak** — consecutive weeks you've trained. 🔥
- **Weekly progress ring** — workouts this week vs. your weekly target.
- **Total volume** — cumulative weight moved across every logged set.
- **History** — every workout, with per-set breakdown and volume.
- **Local & private** — everything is stored in your browser via `localStorage`. No account, no server.

## Tech stack

- [React 18](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)
- [Vite](https://vite.dev/) for dev/build
- Plain CSS (no UI framework)

## Getting started

```bash
npm install
npm run dev      # start the dev server (http://localhost:5173)
```

### Build for production

```bash
npm run build    # type-check + bundle to dist/
npm run preview  # preview the production build
```

## Project structure

```
src/
  App.tsx      # UI + app state
  stats.ts     # streak, weekly count, volume, countdown helpers
  storage.ts   # localStorage load/save + default goal
  types.ts     # Workout / Set / Goal types
  index.css    # styles
```

## License

MIT
