-- Let authenticated contestants subscribe to their own contest's live room.
drop policy if exists "contestants read their live room" on public.contest_rooms;
create policy "contestants read their live room"
on public.contest_rooms for select to authenticated
using (exists (
  select 1 from public.contest_participants cp
  where cp.contest_id = contest_rooms.contest_id
    and cp.contestant_id = (select auth.uid())
));

-- Safe read API for contestants: returns prompt/options but never correct_option.
create or replace function public.get_contest_state(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
  v_question public.questions%rowtype;
  v_score integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.contest_participants cp
    where cp.contest_id=p_contest_id and cp.contestant_id=v_uid
  ) then raise exception 'Not a participant in this contest'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id;
  if not found then return jsonb_build_object('phase','idle'); end if;
  if v_room.active_question_id is not null then
    select * into v_question from public.questions where id=v_room.active_question_id;
  end if;
  select total_score into v_score from public.contest_participants where contest_id=p_contest_id and contestant_id=v_uid;
  return jsonb_build_object(
    'phase',v_room.phase,
    'active_question_id',v_room.active_question_id,
    'active_contestant_id',v_room.active_contestant_id,
    'bonus_winner_id',v_room.bonus_winner_id,
    'phase_started_at',v_room.phase_started_at,
    'deadline_at',v_room.deadline_at,
    'version',v_room.version,
    'your_score',coalesce(v_score,0),
    'question',case when v_question.id is null then null else jsonb_build_object(
      'id',v_question.id,'prompt',v_question.prompt,'kind',v_question.kind,'options',v_question.options
    ) end
  );
end;
$$;
revoke all on function public.get_contest_state(uuid) from public,anon;
grant execute on function public.get_contest_state(uuid) to authenticated;
