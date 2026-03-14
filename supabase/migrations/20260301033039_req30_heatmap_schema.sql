-- REQ-30: Muscle fatigue heatmap schema, RLS, and RPC
-- Safe to run multiple times (idempotent where possible).

begin;

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) Core tables
-- -----------------------------------------------------------------------------
create table if not exists public.muscles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  display_name text not null,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  name text not null,
  category text not null,
  exercise_type varchar not null check (exercise_type in ('cardio', 'weight')),
  muscle_size varchar not null check (muscle_size in ('large', 'small')),
  equipment text not null,
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

create index if not exists idx_workout_logs_created_at
  on public.workout_logs (created_at desc);

create index if not exists idx_exercises_exercise_type
  on public.exercises (exercise_type);

create index if not exists idx_exercises_muscle_size
  on public.exercises (muscle_size);

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

drop trigger if exists trg_workout_logs_set_updated_at on public.workout_logs;
create trigger trg_workout_logs_set_updated_at
before update on public.workout_logs
for each row
execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4) RLS
-- -----------------------------------------------------------------------------
alter table public.muscles enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_muscle_mapping enable row level security;
alter table public.workout_logs enable row level security;

drop policy if exists muscles_select_authenticated on public.muscles;
create policy muscles_select_authenticated
on public.muscles
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
  -- Enforce strict ownership access for client calls.
  if auth.role() <> 'service_role' and auth.uid() is distinct from p_user_id then
    raise exception using
      errcode = '42501',
      message = 'forbidden: you can only request your own heatmap';
  end if;

  with muscle_last_trained as (
    select
      emm.muscle_id,
      max(wl.performed_at) as last_trained_at
    from public.workout_logs wl
    join public.exercise_muscle_mapping emm
      on emm.exercise_id = wl.exercise_id
    where wl.user_id = p_user_id
    group by emm.muscle_id
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'muscle', m.code,
          'status',
          case
            when mlt.last_trained_at is null then 'green'
            when mlt.last_trained_at >= now() - interval '24 hours' then 'red'
            when mlt.last_trained_at >= now() - interval '48 hours' then 'yellow'
            else 'green'
          end
        )
        order by m.display_order, m.code
      ),
      '[]'::jsonb
    )
  into v_result
  from public.muscles m
  left join muscle_last_trained mlt
    on mlt.muscle_id = m.id;

  return v_result;
end;
$$;

revoke all on function public.get_muscle_heatmap_status(uuid) from public;
grant execute on function public.get_muscle_heatmap_status(uuid) to authenticated, service_role;

commit;
