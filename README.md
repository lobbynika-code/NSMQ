# NSMQ Tournament Platform

Monorepo for three applications sharing one Supabase backend: admin, coordinator and contestant. Includes shared contest timing/scoring helpers and the initial database migration.

## Rules
- Individual student accounts; automatic contestant rotation.
- Main question timer: 30 seconds for calculation, 10 seconds otherwise.
- Main correct +3; main wrong/timeout 0.
- Main wrong/timeout opens a 3-second buzz window. First valid buzz wins and starts a separate 3-second bonus answer timer.
- Bonus correct +1; bonus wrong/timeout -1. No buzz means no penalty.

## Run locally
Node.js 20+, then `npm install`. Copy `.env.example` to `.env.local`, configure the single Supabase project, and run `npm run dev:admin`, `npm run dev:coordinator`, or `npm run dev:contestant`.

## Production warning
Pages are prototypes only. Before a live tournament, implement and test Supabase auth/RLS, server-authoritative timers, atomic first-to-buzz resolution, and transactional scoring. Correct answers must never be exposed to contestants before a question closes.