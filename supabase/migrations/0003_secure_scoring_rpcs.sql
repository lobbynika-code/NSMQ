create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function public.submit_main_answer(p_contest_id uuid, p_question_id uuid, p_answer_option smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
  v_question public.questions%rowtype;
  v_correct boolean;
  v_points integer := 0;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_answer_option not between 0 and 3 then raise exception 'Invalid answer option'; end if;
  select * into v_room from public.contest_rooms where contest_id = p_contest_id for update;
  if not found then raise exception 'Contest room not initialized'; end if;
  if v_room.phase <> 'main_active' or v_room.active_question_id <> p_question_id then raise exception 'Main question is not active'; end if;
  if v_room.deadline_at is null or clock_timestamp() > v_room.deadline_at then raise exception 'Main answer deadline passed'; end if;
  if v_room.active_contestant_id <> v_uid then raise exception 'Not your turn'; end if;
  select * into v_question from public.questions where id = p_question_id;
  if not found then raise exception 'Question not found'; end if;
  v_correct := p_answer_option = v_question.correct_option;
  if v_correct then v_points := 3; end if;
  insert into public.answer_attempts(contest_id,question_id,contestant_id,answer_option,answer_type,is_correct,points_awarded)
  values(p_contest_id,p_question_id,v_uid,p_answer_option,'main',v_correct,v_points);
  update public.contest_participants set total_score = total_score + v_points where contest_id = p_contest_id and contestant_id = v_uid;
  if v_correct then
    update public.contest_rooms set phase='round_ended',deadline_at=null,version=version+1,updated_at=now() where contest_id=p_contest_id;
  else
    update public.contest_rooms set phase='buzz_open',phase_started_at=clock_timestamp(),deadline_at=clock_timestamp()+interval '3 seconds',version=version+1,updated_at=now() where contest_id=p_contest_id;
  end if;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'main_answer_submitted',jsonb_build_object('question_id',p_question_id,'correct',v_correct,'points',v_points));
  return jsonb_build_object('correct',v_correct,'points',v_points,'phase',case when v_correct then 'round_ended' else 'buzz_open' end);
end;
$$;

create or replace function public.buzz_in(p_contest_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id for update;
  if not found or v_room.phase <> 'buzz_open' or v_room.active_question_id <> p_question_id or v_room.deadline_at is null or v_now > v_room.deadline_at then
    raise exception 'Buzz window is closed';
  end if;
  if not exists(select 1 from public.contest_participants where contest_id=p_contest_id and contestant_id=v_uid) then raise exception 'Not a participant in this contest'; end if;
  if exists(select 1 from public.buzz_attempts where contest_id=p_contest_id and question_id=p_question_id and contestant_id=v_uid) then raise exception 'Already buzzed on this question'; end if;
  insert into public.buzz_attempts(contest_id,question_id,contestant_id,received_at,accepted)
  values(p_contest_id,p_question_id,v_uid,v_now,true);
  update public.contest_rooms set phase='bonus_active',bonus_winner_id=v_uid,active_contestant_id=v_uid,phase_started_at=v_now,deadline_at=v_now+interval '3 seconds',version=version+1,updated_at=now()
  where contest_id=p_contest_id;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'buzz_won',jsonb_build_object('question_id',p_question_id));
  return jsonb_build_object('accepted',true,'phase','bonus_active','deadline_at',v_now+interval '3 seconds');
end;
$$;

create or replace function public.submit_bonus_answer(p_contest_id uuid, p_question_id uuid, p_answer_option smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.contest_rooms%rowtype;
  v_question public.questions%rowtype;
  v_correct boolean;
  v_points integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_answer_option not between 0 and 3 then raise exception 'Invalid answer option'; end if;
  select * into v_room from public.contest_rooms where contest_id=p_contest_id for update;
  if not found or v_room.phase <> 'bonus_active' or v_room.active_question_id <> p_question_id or v_room.bonus_winner_id <> v_uid then raise exception 'You did not win this bonus opportunity'; end if;
  if v_room.deadline_at is null or clock_timestamp() > v_room.deadline_at then raise exception 'Bonus answer deadline passed'; end if;
  select * into v_question from public.questions where id=p_question_id;
  if not found then raise exception 'Question not found'; end if;
  v_correct := p_answer_option = v_question.correct_option;
  v_points := case when v_correct then 1 else -1 end;
  insert into public.answer_attempts(contest_id,question_id,contestant_id,answer_option,answer_type,is_correct,points_awarded)
  values(p_contest_id,p_question_id,v_uid,p_answer_option,'bonus',v_correct,v_points);
  update public.contest_participants set total_score=total_score+v_points where contest_id=p_contest_id and contestant_id=v_uid;
  update public.contest_rooms set phase='round_ended',deadline_at=null,version=version+1,updated_at=now() where contest_id=p_contest_id;
  insert into public.contest_events(contest_id,actor_id,event_type,payload)
  values(p_contest_id,v_uid,'bonus_answer_submitted',jsonb_build_object('question_id',p_question_id,'correct',v_correct,'points',v_points));
  return jsonb_build_object('correct',v_correct,'points',v_points,'phase','round_ended');
end;
$$;

revoke all on function public.submit_main_answer(uuid,uuid,smallint) from public, anon;
revoke all on function public.buzz_in(uuid,uuid) from public, anon;
revoke all on function public.submit_bonus_answer(uuid,uuid,smallint) from public, anon;
grant execute on function public.submit_main_answer(uuid,uuid,smallint) to authenticated;
grant execute on function public.buzz_in(uuid,uuid) to authenticated;
grant execute on function public.submit_bonus_answer(uuid,uuid,smallint) to authenticated;
