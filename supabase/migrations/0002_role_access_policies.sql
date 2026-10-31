-- Role-aware access rules for NSMQ operations.
-- Clients never receive direct write access to live state, answer attempts, buzz winners, or scores.
drop policy if exists "users can read their own roles" on public.user_roles;
create policy "users can read their own roles"
on public.user_roles for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "published tournaments are visible" on public.tournaments;
create policy "published tournaments are visible"
on public.tournaments for select to authenticated
using (status in ('published','registration_open','in_progress','completed'));

drop policy if exists "admins manage tournaments" on public.tournaments;
create policy "admins manage tournaments"
on public.tournaments for all to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'))
with check (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'));

drop policy if exists "admins manage registrations" on public.registrations;
create policy "admins manage registrations"
on public.registrations for all to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'))
with check (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'));

drop policy if exists "admins manage contests" on public.contests;
create policy "admins manage contests"
on public.contests for all to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'))
with check (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'));

drop policy if exists "coordinators can read contests" on public.contests;
create policy "coordinators can read contests"
on public.contests for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'coordinator'));

drop policy if exists "contest operators read rounds" on public.rounds;
create policy "contest operators read rounds"
on public.rounds for select to authenticated
using (exists (
 select 1 from public.contests c
 join public.user_roles r on r.user_id = (select auth.uid())
 where c.id = rounds.contest_id and r.role in ('admin','coordinator')
));

drop policy if exists "admins manage rounds" on public.rounds;
create policy "admins manage rounds"
on public.rounds for all to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'))
with check (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'));

drop policy if exists "contest operators read question keys" on public.questions;
create policy "contest operators read question keys"
on public.questions for select to authenticated
using (exists (
 select 1 from public.rounds rd
 join public.contests c on c.id = rd.contest_id
 join public.user_roles r on r.user_id = (select auth.uid())
 where rd.id = questions.round_id and r.role in ('admin','coordinator')
));

drop policy if exists "admins manage questions" on public.questions;
create policy "admins manage questions"
on public.questions for all to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'))
with check (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'admin'));

drop policy if exists "contest operators read participants" on public.contest_participants;
create policy "contest operators read participants"
on public.contest_participants for select to authenticated
using (exists (
 select 1 from public.contests c
 join public.user_roles r on r.user_id = (select auth.uid())
 where c.id = contest_participants.contest_id and r.role in ('admin','coordinator')
));

drop policy if exists "contest operators read rooms" on public.contest_rooms;
create policy "contest operators read rooms"
on public.contest_rooms for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role in ('admin','coordinator')));

drop policy if exists "contest operators read answer attempts" on public.answer_attempts;
create policy "contest operators read answer attempts"
on public.answer_attempts for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role in ('admin','coordinator')));

drop policy if exists "contest operators read buzz attempts" on public.buzz_attempts;
create policy "contest operators read buzz attempts"
on public.buzz_attempts for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role in ('admin','coordinator')));

drop policy if exists "contest operators read events" on public.contest_events;
create policy "contest operators read events"
on public.contest_events for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role in ('admin','coordinator')));

create index if not exists registrations_contestant_idx on public.registrations(contestant_id);
create index if not exists participants_contestant_idx on public.contest_participants(contestant_id);
create index if not exists answer_attempts_contestant_idx on public.answer_attempts(contestant_id);
create index if not exists answer_attempts_question_idx on public.answer_attempts(question_id);
create index if not exists buzz_attempts_contestant_idx on public.buzz_attempts(contestant_id);
create index if not exists buzz_attempts_question_idx on public.buzz_attempts(question_id);
create index if not exists events_actor_idx on public.contest_events(actor_id);
create index if not exists rooms_active_question_idx on public.contest_rooms(active_question_id);
create index if not exists rooms_active_contestant_idx on public.contest_rooms(active_contestant_id);
create index if not exists rooms_bonus_winner_idx on public.contest_rooms(bonus_winner_id);
create index if not exists contests_tournament_idx on public.contests(tournament_id);
create index if not exists tournaments_created_by_idx on public.tournaments(created_by);
