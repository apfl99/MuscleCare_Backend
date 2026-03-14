-- REQ-30: Muscle fatigue heatmap schema, RLS, and RPC
-- Safe to run multiple times (idempotent where possible).

begin;

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- -----------------------------------------------------------------------------
-- 1) Core tables
-- -----------------------------------------------------------------------------
create table if not exists public.muscles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  display_name text not null,
  display_name_ko text not null,
  display_name_latin text,
  anatomy_id text,
  parent_muscle_code text,
  side text not null default 'bilateral'
    check (side in ('left', 'right', 'bilateral', 'unknown')),
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.muscles
  add column if not exists display_name_ko text,
  add column if not exists display_name_latin text,
  add column if not exists anatomy_id text,
  add column if not exists parent_muscle_code text,
  add column if not exists side text;

alter table public.muscles
  alter column side set default 'bilateral';

update public.muscles
set
  display_name_ko = coalesce(display_name_ko, display_name),
  side = case
    when side in ('left', 'right', 'bilateral', 'unknown') then side
    else 'bilateral'
  end;

alter table public.muscles
  alter column display_name_ko set not null;

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  name text not null,
  category text not null,
  exercise_type varchar not null check (exercise_type in ('cardio', 'weight')),
  muscle_size varchar not null check (muscle_size in ('large', 'small')),
  primary_muscles text[] not null default '{}'::text[],
  secondary_muscles text[] not null default '{}'::text[],
  equipment text not null,
  biomechanics_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.exercise_muscle_mapping (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  muscle_id uuid not null references public.muscles(id) on delete cascade,
  role text not null check (role in ('primary', 'secondary')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_id, muscle_id)
);

create table if not exists public.muscle_code_aliases (
  alias_code text primary key check (alias_code ~ '^[a-z0-9_]+$'),
  muscle_code text not null references public.muscles(code) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  sets integer check (sets is null or sets > 0),
  reps integer check (reps is null or reps > 0),
  weight_kg numeric(6, 2) check (weight_kg is null or weight_kg >= 0),
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  distance_km numeric(8, 3) check (distance_km is null or distance_km >= 0),
  note text,
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2) Indexes
-- -----------------------------------------------------------------------------
create index if not exists idx_workout_logs_user_id
  on public.workout_logs (user_id);

create index if not exists idx_exercises_name_trgm
  on public.exercises
  using gin (name gin_trgm_ops);

create index if not exists idx_exercises_primary_muscles_gin
  on public.exercises using gin (primary_muscles);

create index if not exists idx_exercises_secondary_muscles_gin
  on public.exercises using gin (secondary_muscles);

create unique index if not exists idx_muscles_anatomy_id_unique
  on public.muscles (anatomy_id)
  where anatomy_id is not null;

create index if not exists idx_muscles_parent_muscle_code
  on public.muscles (parent_muscle_code);

create index if not exists idx_muscle_code_aliases_muscle_code
  on public.muscle_code_aliases (muscle_code);

create index if not exists idx_exercises_exercise_type
  on public.exercises (exercise_type);

create index if not exists idx_exercises_muscle_size
  on public.exercises (muscle_size);

create index if not exists idx_workout_logs_created_at
  on public.workout_logs (created_at desc);

create index if not exists idx_workout_logs_user_created_at
  on public.workout_logs (user_id, created_at desc);

create index if not exists idx_workout_logs_user_performed_at
  on public.workout_logs (user_id, performed_at desc);

create index if not exists idx_workout_logs_exercise_id
  on public.workout_logs (exercise_id);

create index if not exists idx_exercise_muscle_mapping_exercise_id
  on public.exercise_muscle_mapping (exercise_id);

create index if not exists idx_exercise_muscle_mapping_muscle_id
  on public.exercise_muscle_mapping (muscle_id);

-- -----------------------------------------------------------------------------
-- 3) updated_at trigger
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

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

create or replace function public.is_placeholder_muscle_text(p_text text)
returns boolean
language sql
immutable
parallel safe
as $$
  with normalized as (
    select regexp_replace(lower(trim(coalesce(p_text, ''))), '\s+', ' ', 'g') as v
  )
  select v in (
    '',
    '근육부위',
    '근육 부위',
    '기타 근육',
    'unknown',
    'other',
    'placeholder'
  )
  from normalized;
$$;

create or replace function public.resolve_muscle_code(p_text text)
returns text
language sql
stable
set search_path = public
as $$
  with normalized as (
    select public.normalize_muscle_code(p_text) as code
  )
  select coalesce(
    (
      select mca.muscle_code
      from public.muscle_code_aliases mca
      join normalized n
        on n.code = mca.alias_code
      limit 1
    ),
    (
      select m.code
      from public.muscles m
      join normalized n
        on n.code = m.code
      limit 1
    )
  );
$$;

drop trigger if exists trg_muscles_set_updated_at on public.muscles;
create trigger trg_muscles_set_updated_at
before update on public.muscles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_exercises_set_updated_at on public.exercises;
create trigger trg_exercises_set_updated_at
before update on public.exercises
for each row
execute function public.set_updated_at();

drop trigger if exists trg_exercise_muscle_mapping_set_updated_at on public.exercise_muscle_mapping;
create trigger trg_exercise_muscle_mapping_set_updated_at
before update on public.exercise_muscle_mapping
for each row
execute function public.set_updated_at();

drop trigger if exists trg_muscle_code_aliases_set_updated_at on public.muscle_code_aliases;
create trigger trg_muscle_code_aliases_set_updated_at
before update on public.muscle_code_aliases
for each row
execute function public.set_updated_at();

drop trigger if exists trg_workout_logs_set_updated_at on public.workout_logs;
create trigger trg_workout_logs_set_updated_at
before update on public.workout_logs
for each row
execute function public.set_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'muscles_parent_muscle_code_fkey'
      and conrelid = 'public.muscles'::regclass
  ) then
    alter table public.muscles
      add constraint muscles_parent_muscle_code_fkey
      foreign key (parent_muscle_code)
      references public.muscles(code)
      on update cascade
      on delete set null;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'muscles_side_check'
      and conrelid = 'public.muscles'::regclass
  ) then
    alter table public.muscles
      add constraint muscles_side_check
      check (side in ('left', 'right', 'bilateral', 'unknown'));
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'muscles_display_name_ko_not_placeholder_check'
      and conrelid = 'public.muscles'::regclass
  ) then
    alter table public.muscles
      add constraint muscles_display_name_ko_not_placeholder_check
      check (not public.is_placeholder_muscle_text(display_name_ko));
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

  if v_exercise_type = 'cardio' and new.duration_minutes is null then
    raise exception using
      errcode = '23514',
      message = 'cardio logs require duration_minutes';
  end if;

  if v_exercise_type = 'weight' and (new.sets is null or new.reps is null) then
    raise exception using
      errcode = '23514',
      message = 'weight logs require sets and reps';
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
-- 4) RLS
-- -----------------------------------------------------------------------------
alter table public.muscles enable row level security;
alter table public.muscle_code_aliases enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_muscle_mapping enable row level security;
alter table public.workout_logs enable row level security;

drop policy if exists muscles_select_authenticated on public.muscles;
create policy muscles_select_authenticated
on public.muscles
for select
to authenticated
using (true);

drop policy if exists muscle_code_aliases_select_authenticated on public.muscle_code_aliases;
create policy muscle_code_aliases_select_authenticated
on public.muscle_code_aliases
for select
to authenticated
using (true);

drop policy if exists exercises_select_authenticated on public.exercises;
create policy exercises_select_authenticated
on public.exercises
for select
to authenticated
using (true);

drop policy if exists exercise_muscle_mapping_select_authenticated on public.exercise_muscle_mapping;
create policy exercise_muscle_mapping_select_authenticated
on public.exercise_muscle_mapping
for select
to authenticated
using (true);

drop policy if exists workout_logs_select_own on public.workout_logs;
create policy workout_logs_select_own
on public.workout_logs
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists workout_logs_insert_own on public.workout_logs;
create policy workout_logs_insert_own
on public.workout_logs
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists workout_logs_update_own on public.workout_logs;
create policy workout_logs_update_own
on public.workout_logs
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists workout_logs_delete_own on public.workout_logs;
create policy workout_logs_delete_own
on public.workout_logs
for delete
to authenticated
using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 5) RPC: get_muscle_heatmap_status
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

  with raw_contrib as (
    select
      public.resolve_muscle_code(pm.muscle_code) as muscle_code,
      1.0::numeric as role_weight,
      wl.performed_at
    from public.workout_logs wl
    join public.exercises e
      on e.id = wl.exercise_id
    cross join lateral unnest(coalesce(e.primary_muscles, '{}'::text[])) as pm(muscle_code)
    where wl.user_id = p_user_id
      and wl.performed_at >= now() - interval '14 days'

    union all

    select
      public.resolve_muscle_code(sm.muscle_code) as muscle_code,
      0.5::numeric as role_weight,
      wl.performed_at
    from public.workout_logs wl
    join public.exercises e
      on e.id = wl.exercise_id
    cross join lateral unnest(coalesce(e.secondary_muscles, '{}'::text[])) as sm(muscle_code)
    where wl.user_id = p_user_id
      and wl.performed_at >= now() - interval '14 days'
  ),
  weighted as (
    select
      rc.muscle_code,
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
    where rc.muscle_code is not null
    group by rc.muscle_code
  ),
  merged as (
    select
      m.code as muscle_code,
      m.display_name_ko,
      m.display_name_latin,
      m.anatomy_id,
      m.parent_muscle_code,
      m.side,
      m.display_order,
      coalesce(w.fatigue_score, 0)::numeric(10, 3) as fatigue_score,
      w.last_trained_at
    from public.muscles m
    left join weighted w
      on w.muscle_code = m.code
    where not public.is_placeholder_muscle_text(m.display_name_ko)
      and m.code ~ '^[a-z0-9_]+$'
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'muscle', merged.muscle_code, -- backward compatibility
          'muscle_code', merged.muscle_code,
          'display_name_ko', merged.display_name_ko,
          'display_name_latin', merged.display_name_latin,
          'anatomy_id', merged.anatomy_id,
          'parent_muscle_code', merged.parent_muscle_code,
          'side', merged.side,
          'fatigue_score', merged.fatigue_score,
          'status',
          case
            when merged.fatigue_score >= 1.20 then 'red'
            when merged.fatigue_score >= 0.45 then 'yellow'
            else 'green'
          end,
          'last_trained_at', merged.last_trained_at
        )
        order by merged.display_order, merged.muscle_code
      ),
      '[]'::jsonb
    )
  into v_result
  from merged;

  return v_result;
end;
$$;

revoke all on function public.get_muscle_heatmap_status(uuid) from public;
grant execute on function public.get_muscle_heatmap_status(uuid) to authenticated, service_role;

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
    select trim(coalesce(p_keyword, '')) as q
  )
  select
    e.id,
    e.name,
    e.category,
    e.exercise_type,
    e.muscle_size,
    coalesce(e.primary_muscles, '{}'::text[]) as primary_muscles,
    coalesce(e.secondary_muscles, '{}'::text[]) as secondary_muscles
  from public.exercises e
  cross join kw
  where kw.q <> ''
    and e.name ilike '%' || kw.q || '%'
  order by similarity(e.name, kw.q) desc, e.name asc
  limit 20;
$$;

revoke all on function public.search_exercises(text) from public;
grant execute on function public.search_exercises(text) to authenticated, service_role;

commit;
