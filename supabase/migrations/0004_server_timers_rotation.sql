create or replace function public.start_next_main_question(p_contest_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_contest public.contests%rowtype;
  v_question public.questions%rowtype;
  v_participant public.contest_participants%rowtype;
  v_count integer;
  v_deadline timestamptz;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.user_roles r where r.user_id=v_uid and r.role in ('admin','coordinator')) then raise exception 'Coordinator or admin role required'; end if;
  select * into v_contest from public.contests where id=p_contest_id for update;
  if not found then raise exception 'Contest not found'; end if;
  select * into v_question from public.questions where id=p_question_id;
  if not found then raise exception 'Question not found'; end if;
  if not exists(select 1 from public.rounds rd where rd.id=v_question.round_id and rd.contest_id=p_contest_id) then raise exception 'Question does not belong to this contest'; end if;
  select count(*) into v_count from public.contest_participants where contest_id=p_contest_id;
  if v_count=0 then raise exception 'No contestants assigned to this contest'; end if;
  select * into v_participant from public.contest_participants
  where contest_id=p_contest_id and rotation_position > v_contest.rotation_index
  order by rotation_position limit 1;
  if not found then
    select * into v_participant from public.contest_participants where contest_id=p_contest_id order by rotation_position limit 1;
  end if;
  v_deadline := clock_timestamp() + case when v_question.kind='calculation' then interval '30 seconds' else interval '10 seconds' end;
  update public.contests set rotation_index=v_participant.rotation_position,status='in_progress' where id=p_contest_id;
  insert into public.contest_rooms(contest_id,phase,active_question_id,active_contestant_id,bonus_winner_id,phase_started_at,deadline_at,version,updated_at)
  values(p_contest_id,'main_active',p_question_id,v_participant.contestant_id,null,clock_timestamp(),v_deadline,1,now())
  on conflict(contest_id) do update set phase='main_active',active_question_id=excluded.active_question_id,active_contestant_id=excluded.active_contestant_id,bonus_winner_id=null,phase_started_at=excluded.phase_started_at,deadline_at=excluded.deadline_at,version=public.contest_rooms.version+1,updated_at=now();
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'main_question_started',jsonb_build_object('question_id',p_question_id,'contestant_id',v_participant.contestant_id,'deadline_at',v_deadline));
  return jsonb_build_object('phase','main_active','question_id',p_question_id,'contestant_id',v_participant.contestant_id,'deadline_at',v_deadline,'seconds',case when v_question.kind='calculation' then 30 else 10 end);
end;
$$;

create or replace function public.expire_main_question(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.user_roles r where r.user_id=v_uid and r.role in ('admin','coordinator')) then raise exception 'Coordinator or admin role required'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id for update;
  if not found or v_room.phase <> 'main_active' or v_room.deadline_at is null or clock_timestamp() < v_room.deadline_at then raise exception 'Main timer has not expired'; end if;
  insert into public.answer_attempts(contest_id,question_id,contestant_id,answer_option,answer_type,is_correct,points_awarded)
  values(p_contest_id,v_room.active_question_id,v_room.active_contestant_id,null,'main',false,0)
  on conflict(contest_id,question_id,contestant_id,answer_type) do nothing;
  update public.contest_rooms set phase='buzz_open',phase_started_at=clock_timestamp(),deadline_at=clock_timestamp()+interval '3 seconds',version=version+1,updated_at=now() where contest_id=p_contest_id;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'main_question_timed_out',jsonb_build_object('question_id',v_room.active_question_id));
  return jsonb_build_object('phase','buzz_open','deadline_at',clock_timestamp()+interval '3 seconds');
end;
$$;

create or replace function public.expire_buzz_window(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.user_roles r where r.user_id=v_uid and r.role in ('admin','coordinator')) then raise exception 'Coordinator or admin role required'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id for update;
  if not found or v_room.phase <> 'buzz_open' or v_room.deadline_at is null or clock_timestamp() < v_room.deadline_at then raise exception 'Buzz window has not expired'; end if;
  update public.contest_rooms set phase='round_ended',deadline_at=null,version=version+1,updated_at=now() where contest_id=p_contest_id;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'buzz_window_expired',jsonb_build_object('question_id',v_room.active_question_id));
  return jsonb_build_object('phase','round_ended');
end;
$$;

create or replace function public.expire_bonus_answer(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.user_roles r where r.user_id=v_uid and r.role in ('admin','coordinator')) then raise exception 'Coordinator or admin role required'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id for update;
  if not found or v_room.phase <> 'bonus_active' or v_room.deadline_at is null or clock_timestamp() < v_room.deadline_at then raise exception 'Bonus timer has not expired'; end if;
  insert into public.answer_attempts(contest_id,question_id,contestant_id,answer_option,answer_type,is_correct,points_awarded)
  values(p_contest_id,v_room.active_question_id,v_room.bonus_winner_id,null,'bonus',false,-1)
  on conflict(contest_id,question_id,contestant_id,answer_type) do nothing;
  update public.contest_participants set total_score=total_score-1 where contest_id=p_contest_id and contestant_id=v_room.bonus_winner_id;
  update public.contest_rooms set phase='round_ended',deadline_at=null,version=version+1,updated_at=now() where contest_id=p_contest_id;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'bonus_answer_timed_out',jsonb_build_object('question_id',v_room.active_question_id,'contestant_id',v_room.bonus_winner_id,'points',-1));
  return jsonb_build_object('phase','round_ended','points',-1);
end;
$$;

revoke all on function public.start_next_main_question(uuid,uuid) from public,anon;
revoke all on function public.expire_main_question(uuid) from public,anon;
revoke all on function public.expire_buzz_window(uuid) from public,anon;
revoke all on function public.expire_bonus_answer(uuid) from public,anon;
grant execute on function public.start_next_main_question(uuid,uuid) to authenticated;
grant execute on function public.expire_main_question(uuid) to authenticated;
grant execute on function public.expire_buzz_window(uuid) to authenticated;
grant execute on function public.expire_bonus_answer(uuid) to authenticated;
