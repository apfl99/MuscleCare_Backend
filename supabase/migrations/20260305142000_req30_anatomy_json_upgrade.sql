-- REQ-30 Sprint: anatomy JSON non-destructive migration and RPC upgrade

begin;

-- -----------------------------------------------------------------------------
-- 1) Non-destructive schema update for anatomy arrays
-- -----------------------------------------------------------------------------
alter table public.exercises
  add column if not exists primary_muscles text[] not null default '{}'::text[],
  add column if not exists secondary_muscles text[] not null default '{}'::text[],
  add column if not exists biomechanics_note text;

-- equipment already exists in current production schema.
-- Keep existing definition untouched to avoid breaking compatibility.
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'exercises'
      and column_name = 'equipment'
  ) then
    alter table public.exercises
      add column equipment varchar;
  end if;
end;
$$;

create index if not exists idx_exercises_primary_muscles_gin
  on public.exercises using gin (primary_muscles);

create index if not exists idx_exercises_secondary_muscles_gin
  on public.exercises using gin (secondary_muscles);

create or replace function public.normalize_muscle_code(p_text text)
returns text
language sql
immutable
parallel safe
as $$
  select nullif(
    regexp_replace(
      regexp_replace(lower(trim(coalesce(p_text, ''))), '[^a-z0-9]+', '_', 'g'),
      '^_+|_+$',
      '',
      'g'
    ),
    ''
  );
$$;

-- -----------------------------------------------------------------------------
-- 2) search_exercises response extension (logic preserved)
-- -----------------------------------------------------------------------------
drop function if exists public.search_exercises(text);

create or replace function public.search_exercises(p_keyword text)
returns table (
  id uuid,
  name text,
  category text,
  exercise_type varchar,
  muscle_size varchar,
  primary_muscles text[],
  secondary_muscles text[]
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
      coalesce(e.primary_muscles, '{}'::text[]) as primary_muscles,
      coalesce(e.secondary_muscles, '{}'::text[]) as secondary_muscles,
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
      coalesce(e.primary_muscles, '{}'::text[]) as primary_muscles,
      coalesce(e.secondary_muscles, '{}'::text[]) as secondary_muscles,
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
      s.primary_muscles,
      s.secondary_muscles,
      max(s.score) as score
    from (
      select * from direct_match
      union all
      select * from alias_match
    ) s
    group by
      s.id,
      s.name,
      s.category,
      s.exercise_type,
      s.muscle_size,
      s.primary_muscles,
      s.secondary_muscles
  )
  select
    r.id,
    r.name,
    r.category,
    r.exercise_type,
    r.muscle_size,
    r.primary_muscles,
    r.secondary_muscles
  from ranked r
  order by r.score desc, r.name asc
  limit 20;
$$;

revoke all on function public.search_exercises(text) from public;
grant execute on function public.search_exercises(text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3) get_muscle_heatmap_status anatomy-weighted scoring (primary=1.0, secondary=0.5)
-- -----------------------------------------------------------------------------
create or replace function public.get_muscle_heatmap_status(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.role() <> 'service_role' and auth.uid() is distinct from p_user_id then
    raise exception using
      errcode = '42501',
      message = 'forbidden: you can only request your own heatmap';
  end if;

  with exercise_muscle_catalog as (
    select distinct public.normalize_muscle_code(pm.muscle_id) as muscle_id
    from public.exercises e
    cross join lateral unnest(coalesce(e.primary_muscles, '{}'::text[])) as pm(muscle_id)
    union
    select distinct public.normalize_muscle_code(sm.muscle_id) as muscle_id
    from public.exercises e
    cross join lateral unnest(coalesce(e.secondary_muscles, '{}'::text[])) as sm(muscle_id)
  ),
  base_muscles as (
    select
      x.muscle_id,
      min(x.display_order) as display_order
    from (
      select m.code as muscle_id, m.display_order
      from public.muscles m
      union all
      select emc.muscle_id, 9999 as display_order
      from exercise_muscle_catalog emc
      where emc.muscle_id is not null
    ) x
    group by x.muscle_id
  ),
  raw_contrib as (
    select
      public.normalize_muscle_code(pm.muscle_id) as muscle_id,
      1.0::numeric as role_weight,
      wl.performed_at
    from public.workout_logs wl
    join public.exercises e
      on e.id = wl.exercise_id
    cross join lateral unnest(coalesce(e.primary_muscles, '{}'::text[])) as pm(muscle_id)
    where wl.user_id = p_user_id
      and wl.performed_at >= now() - interval '14 days'

    union all

    select
      public.normalize_muscle_code(sm.muscle_id) as muscle_id,
      0.5::numeric as role_weight,
      wl.performed_at
    from public.workout_logs wl
    join public.exercises e
      on e.id = wl.exercise_id
    cross join lateral unnest(coalesce(e.secondary_muscles, '{}'::text[])) as sm(muscle_id)
    where wl.user_id = p_user_id
      and wl.performed_at >= now() - interval '14 days'
  ),
  weighted as (
    select
      rc.muscle_id,
      sum(
        rc.role_weight *
        case
          when rc.performed_at >= now() - interval '24 hours' then 1.00
          when rc.performed_at >= now() - interval '48 hours' then 0.60
          when rc.performed_at >= now() - interval '72 hours' then 0.30
          when rc.performed_at >= now() - interval '7 days' then 0.15
          else 0.05
        end
      )::numeric(10, 3) as fatigue_score,
      max(rc.performed_at) as last_trained_at
    from raw_contrib rc
    where rc.muscle_id is not null
    group by rc.muscle_id
  ),
  merged as (
    select
      bm.muscle_id,
      bm.display_order,
      coalesce(w.fatigue_score, 0)::numeric(10, 3) as fatigue_score,
      w.last_trained_at
    from base_muscles bm
    left join weighted w
      on w.muscle_id = bm.muscle_id
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'muscle', m.muscle_id,
          'fatigue_score', m.fatigue_score,
          'status',
          case
            when m.fatigue_score >= 1.20 then 'red'
            when m.fatigue_score >= 0.45 then 'yellow'
            else 'green'
          end,
          'last_trained_at', m.last_trained_at
        )
        order by m.display_order, m.muscle_id
      ),
      '[]'::jsonb
    )
  into v_result
  from merged m;

  return v_result;
end;
$$;

revoke all on function public.get_muscle_heatmap_status(uuid) from public;
grant execute on function public.get_muscle_heatmap_status(uuid) to authenticated, service_role;

commit;
