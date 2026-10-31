# NSMQ Tournament Platform

Monorepo for three Next.js apps sharing one Supabase backend: admin, coordinator and contestant.

## Competition rules
- Individual students; server-managed automatic contestant rotation.
- Main timer: 30 seconds for calculation questions, 10 seconds otherwise.
- Correct main answer: +3; wrong or timed-out main answer: 0.
- Wrong or timed-out main answer opens a 3-second buzz window.
- First valid buzz wins a separate 3-second bonus-answer window.
- Correct bonus: +1; wrong or timed-out bonus: -1.

## Current status
- Admin, coordinator and contestant preview apps are deployed on Vercel.
- Supabase schema and role-aware row-level security policies are applied.
- Server-side RPCs exist for starting/rotating questions, main answers, buzz-in, bonus answers, and timer expiry.
- Scoring and contest transitions are calculated server-side with row locking.
- Correct-answer access is restricted to admin/coordinator roles.
- The UIs are still prototypes and are **not yet connected to Supabase Auth, Realtime or the RPCs**. Do not use for a live event until integration and end-to-end testing are complete.

## Local development
Requires Node.js 20+.
```bash
npm install
cp .env.example .env.local
npm run dev:admin
# or npm run dev:coordinator
# or npm run dev:contestant
```

Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in local and Vercel environments. Never expose a Supabase secret/service-role key in browser code or a NEXT_PUBLIC variable.

## Server RPCs
- start_next_main_question — coordinator/admin starts a question; server rotates contestant and sets the correct timer.
- submit_main_answer — validates contestant turn and deadline; correct answer +3, wrong answer opens buzz.
- expire_main_question — records timeout and opens 3-second buzz.
- buzz_in — atomically accepts the first valid buzz and starts the 3-second bonus timer.
- submit_bonus_answer — correct +1, wrong -1.
- expire_bonus_answer — records timeout and awards -1.
- expire_buzz_window — closes buzz when no valid buzz arrives.

## Before a live event
1. Implement sign-in and secure role provisioning; users must never assign themselves admin/coordinator roles.
2. Connect UIs to Auth, Realtime and the RPCs above.
3. Add coordinator-side deadline expiry handling and test simultaneous buzz requests.
4. End-to-end test access control, timer boundaries, repeated submissions, rotation and scoring.
