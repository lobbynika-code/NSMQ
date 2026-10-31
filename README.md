# NSMQ Tournament Platform

Monorepo for three apps sharing one Supabase backend:
- `apps/admin` — tournament setup, rounds and question authoring
- `apps/coordinator` — live room controls and contestant rotation
- `apps/contestant` — student portal and question UI
- `packages/contest-engine` — shared timing/scoring constants
- `supabase/migrations` — database schema

## Rules
- Individual student accounts.
- Automatic contestant rotation.
- Main question: 30 seconds for calculation, 10 seconds for non-calculation.
- Main correct +3; wrong or timeout 0.
- A wrong/timeout main answer opens a 3-second buzz window.
- First valid buzz wins; the winner receives a fresh 3-second bonus-answer timer.
- Bonus correct +1; wrong/timeout -1. No buzz means no bonus penalty.

## Local setup
1. Install Node.js 20+ and npm.
2. Copy `.env.example` to `.env.local` and set the shared Supabase project URL and publishable key.
3. Install with `npm install`.
4. Run `npm run dev:admin`, `npm run dev:coordinator`, or `npm run dev:contestant`.

Ports: admin 3001, coordinator 3002, contestant 3003.

## Important
Current app pages are prototypes. Do not use them to run a real contest yet: database-backed authentication, transactional answer scoring, server-authoritative timers, and atomic first-to-buzz resolution must be implemented and tested before production.
