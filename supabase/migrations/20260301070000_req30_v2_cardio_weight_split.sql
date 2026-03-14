-- REQ-30 V2: cardio/weight split and heatmap-ready metadata

begin;

-- -----------------------------------------------------------------------------
-- 1) exercises master enhancement
-- -----------------------------------------------------------------------------
alter table public.exercises
  add column if not exists exercise_type varchar,
  add column if not exists muscle_size varchar;

update public.exercises
set exercise_type = case
  when category = 'cardio' then 'cardio'
  else 'weight'
end
where exercise_type is null;

with primary_muscle_inference as (
  select
    e.id as exercise_id,
    case
      when e.exercise_type = 'cardio' then 'large'
      when max(
        case
          when m.code in (
            'chest', 'upper_chest', 'lats', 'rhomboids', 'spinal_erectors',
            'quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors'
          ) then 1
          else 0
        end
      ) = 1 then 'large'
      else 'small'
    end as inferred_size
  from public.exercises e
  left join public.exercise_muscle_mapping emm
    on emm.exercise_id = e.id
   and emm.role = 'primary'
  left join public.muscles m
    on m.id = emm.muscle_id
  group by e.id, e.exercise_type
)
update public.exercises e
set muscle_size = pmi.inferred_size
from primary_muscle_inference pmi
where e.id = pmi.exercise_id
  and e.muscle_size is null;

update public.exercises
set muscle_size = case
  when exercise_type = 'cardio' then 'large'
  else 'small'
end
where muscle_size is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'exercises_exercise_type_check'
      and conrelid = 'public.exercises'::regclass
  ) then
    alter table public.exercises
      add constraint exercises_exercise_type_check
      check (exercise_type in ('cardio', 'weight'));
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'exercises_muscle_size_check'
      and conrelid = 'public.exercises'::regclass
  ) then
    alter table public.exercises
      add constraint exercises_muscle_size_check
      check (muscle_size in ('large', 'small'));
  end if;
end;
$$;

alter table public.exercises
  alter column exercise_type set not null,
  alter column muscle_size set not null;

create index if not exists idx_exercises_exercise_type
  on public.exercises (exercise_type);

create index if not exists idx_exercises_muscle_size
  on public.exercises (muscle_size);

-- -----------------------------------------------------------------------------
-- 2) workout_logs flexibility for cardio + weight
-- -----------------------------------------------------------------------------
alter table public.workout_logs
  alter column sets drop not null,
  alter column reps drop not null;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'workout_logs'
      and column_name = 'weight'
  ) then
    execute 'alter table public.workout_logs alter column weight drop not null';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'workout_logs'
      and column_name = 'weight_kg'
  ) then
    execute 'alter table public.workout_logs alter column weight_kg drop not null';
  end if;
end;
$$;

alter table public.workout_logs
  add column if not exists duration_minutes integer,
  add column if not exists distance_km numeric(8, 3);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'workout_logs_duration_minutes_positive_check'
      and conrelid = 'public.workout_logs'::regclass
  ) then
    alter table public.workout_logs
      add constraint workout_logs_duration_minutes_positive_check
      check (duration_minutes is null or duration_minutes > 0);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'workout_logs_distance_km_nonnegative_check'
      and conrelid = 'public.workout_logs'::regclass
  ) then
    alter table public.workout_logs
      add constraint workout_logs_distance_km_nonnegative_check
      check (distance_km is null or distance_km >= 0);
  end if;
end;
$$;

create or replace function public.validate_workout_log_payload_by_exercise_type()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exercise_type text;
begin
  select exercise_type
  into v_exercise_type
  from public.exercises
  where id = new.exercise_id;

  if v_exercise_type is null then
    raise exception using
      errcode = '23503',
      message = 'invalid exercise_id for workout_logs';
  end if;

  if v_exercise_type = 'cardio' then
    if new.duration_minutes is null then
      raise exception using
        errcode = '23514',
        message = 'cardio logs require duration_minutes';
    end if;
  elsif v_exercise_type = 'weight' then
    if new.sets is null or new.reps is null then
      raise exception using
        errcode = '23514',
        message = 'weight logs require sets and reps';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_workout_logs_validate_payload on public.workout_logs;
create trigger trg_workout_logs_validate_payload
before insert or update of exercise_id, sets, reps, duration_minutes
on public.workout_logs
for each row
execute function public.validate_workout_log_payload_by_exercise_type();

-- -----------------------------------------------------------------------------
-- 3) search_exercises RPC response enhancement
-- -----------------------------------------------------------------------------
drop function if exists public.search_exercises(text);

create or replace function public.search_exercises(p_keyword text)
returns table (
  id uuid,
  name text,
  category text,
  exercise_type varchar,
  muscle_size varchar
)
language sql
security invoker
set search_path = public
as $$
  with kw as (
    select
      trim(coalesce(p_keyword, '')) as raw,
      public.search_normalize_text(p_keyword) as norm
  ),
  direct_match as (
    select
      e.id,
      e.name,
      e.category,
      e.exercise_type,
      e.muscle_size,
      (
        greatest(
          similarity(e.name, kw.raw),
          similarity(public.search_normalize_text(e.name), kw.norm)
        )
        + case when lower(e.name) = lower(kw.raw) then 1.0 else 0 end
        + case when e.name ilike kw.raw || '%' then 0.35 else 0 end
      ) as score
    from public.exercises e
    cross join kw
    where kw.norm <> ''
      and (
        e.name ilike '%' || kw.raw || '%'
        or public.search_normalize_text(e.name) like '%' || kw.norm || '%'
      )
  ),
  alias_match as (
    select
      e.id,
      e.name,
      e.category,
      e.exercise_type,
      e.muscle_size,
      (
        greatest(
          similarity(a.alias, kw.raw),
          similarity(public.search_normalize_text(a.alias), kw.norm)
        )
        + case when lower(a.alias) = lower(kw.raw) then 1.0 else 0 end
        + case when a.alias ilike kw.raw || '%' then 0.45 else 0 end
        + case
            when kw.norm ~ '^[ㄱ-ㅎ]+$'
             and public.hangul_to_choseong(a.alias) like '%' || kw.norm || '%'
            then 0.8
            else 0
          end
      ) as score
    from public.exercise_search_aliases a
    join public.exercises e
      on e.id = a.exercise_id
    cross join kw
    where kw.norm <> ''
      and (
        a.alias ilike '%' || kw.raw || '%'
        or public.search_normalize_text(a.alias) like '%' || kw.norm || '%'
        or (
          kw.norm ~ '^[ㄱ-ㅎ]+$'
          and public.hangul_to_choseong(a.alias) like '%' || kw.norm || '%'
        )
      )
  ),
  ranked as (
    select
      s.id,
      s.name,
      s.category,
      s.exercise_type,
      s.muscle_size,
      max(s.score) as score
    from (
      select * from direct_match
      union all
      select * from alias_match
    ) s
    group by s.id, s.name, s.category, s.exercise_type, s.muscle_size
  )
  select
    r.id,
    r.name,
    r.category,
    r.exercise_type,
    r.muscle_size
  from ranked r
  order by r.score desc, r.name asc
  limit 20;
$$;

revoke all on function public.search_exercises(text) from public;
grant execute on function public.search_exercises(text) to authenticated, service_role;

commit;
