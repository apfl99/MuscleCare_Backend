-- REQ-30 Sprint: canonical muscle standardization and placeholder elimination

begin;

-- -----------------------------------------------------------------------------
-- 0) Helper functions
-- -----------------------------------------------------------------------------
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
-- 1) muscles master schema hardening
-- -----------------------------------------------------------------------------
alter table public.muscles
  add column if not exists display_name_ko text,
  add column if not exists display_name_latin text,
  add column if not exists anatomy_id text,
  add column if not exists parent_muscle_code text,
  add column if not exists side text;

alter table public.muscles
  alter column side set default 'bilateral';

update public.muscles
set side = 'bilateral'
where side is null or side not in ('left', 'right', 'bilateral', 'unknown');

create temporary table tmp_standard_muscles (
  code text primary key,
  display_name text not null,
  display_name_ko text not null,
  display_name_latin text,
  anatomy_id text,
  parent_muscle_code text,
  side text not null,
  display_order integer not null
) on commit drop;

insert into tmp_standard_muscles (
  code,
  display_name,
  display_name_ko,
  display_name_latin,
  anatomy_id,
  parent_muscle_code,
  side,
  display_order
)
values
  ('chest', 'Chest', '가슴', 'Musculus pectoralis major', null, null, 'bilateral', 10),
  ('upper_chest', 'Upper Chest', '상부 가슴', 'Pars clavicularis musculi pectoralis major', null, 'chest', 'bilateral', 20),
  ('serratus_anterior', 'Serratus Anterior', '전거근', 'Musculus serratus anterior', null, 'chest', 'bilateral', 30),

  ('shoulders', 'Shoulders', '어깨', 'Regio deltoidea', null, null, 'bilateral', 40),
  ('front_deltoid', 'Front Deltoid', '전면 삼각근', 'Pars clavicularis musculi deltoidei', null, 'shoulders', 'bilateral', 50),
  ('lateral_deltoid', 'Lateral Deltoid', '측면 삼각근', 'Pars acromialis musculi deltoidei', null, 'shoulders', 'bilateral', 60),
  ('rear_deltoid', 'Rear Deltoid', '후면 삼각근', 'Pars spinalis musculi deltoidei', null, 'shoulders', 'bilateral', 70),

  ('traps', 'Traps', '승모근', 'Musculus trapezius', null, null, 'bilateral', 80),
  ('upper_trapezius', 'Upper Trapezius', '상부 승모근', 'Pars descendens musculi trapezii', null, 'traps', 'bilateral', 90),
  ('middle_trapezius', 'Middle Trapezius', '중부 승모근', 'Pars transversa musculi trapezii', null, 'traps', 'bilateral', 100),
  ('lower_trapezius', 'Lower Trapezius', '하부 승모근', 'Pars ascendens musculi trapezii', null, 'traps', 'bilateral', 110),

  ('lats', 'Latissimus Dorsi', '광배근', 'Musculus latissimus dorsi', null, null, 'bilateral', 120),
  ('middle_back', 'Middle Back', '중부 등', 'Regio interscapularis', null, null, 'bilateral', 130),
  ('rhomboids', 'Rhomboids', '능형근', 'Musculi rhomboidei', null, 'middle_back', 'bilateral', 140),
  ('lower_back', 'Lower Back', '하부 등', 'Regio lumbalis', null, null, 'bilateral', 150),
  ('spinal_erectors', 'Spinal Erectors', '척추기립근', 'Musculus erector spinae', null, 'lower_back', 'bilateral', 160),

  ('biceps', 'Biceps', '이두근', 'Musculus biceps brachii', null, null, 'bilateral', 170),
  ('triceps', 'Triceps', '삼두근', 'Musculus triceps brachii', null, null, 'bilateral', 180),
  ('forearms', 'Forearms', '전완근', 'Regio antebrachii', null, null, 'bilateral', 190),
  ('forearm_flexors', 'Forearm Flexors', '전완 굴곡근', 'Musculi flexores antebrachii', null, 'forearms', 'bilateral', 200),
  ('forearm_extensors', 'Forearm Extensors', '전완 신전근', 'Musculi extensores antebrachii', null, 'forearms', 'bilateral', 210),

  ('abdominals', 'Abdominals', '복근', 'Musculi abdominis', null, null, 'bilateral', 220),
  ('transverse_abdominis', 'Transverse Abdominis', '복횡근', 'Musculus transversus abdominis', null, 'abdominals', 'bilateral', 230),
  ('abs', 'Rectus Abdominis', '복직근', 'Musculus rectus abdominis', null, 'abdominals', 'bilateral', 240),
  ('obliques', 'Obliques', '복사근', 'Musculus obliquus externus abdominis', null, 'abdominals', 'bilateral', 250),
  ('hip_flexors', 'Hip Flexors', '고관절 굴곡근', 'Musculi flexores coxae', null, 'abdominals', 'bilateral', 260),

  ('glutes', 'Glutes', '둔근', 'Musculus gluteus maximus', null, null, 'bilateral', 270),
  ('abductors', 'Abductors', '외전근', 'Musculi abductores coxae', null, null, 'bilateral', 280),
  ('adductors', 'Adductors', '내전근', 'Musculi adductores femoris', null, null, 'bilateral', 290),
  ('quadriceps', 'Quadriceps', '대퇴사두근', 'Musculus quadriceps femoris', null, null, 'bilateral', 300),
  ('hamstrings', 'Hamstrings', '햄스트링', 'Musculi ischiocrurales', null, null, 'bilateral', 310),
  ('calves', 'Calves', '종아리', 'Musculus gastrocnemius', null, null, 'bilateral', 320),
  ('tibialis_anterior', 'Tibialis Anterior', '전경골근', 'Musculus tibialis anterior', null, null, 'bilateral', 330),

  ('neck', 'Neck', '경부', 'Regio cervicalis', null, null, 'bilateral', 340);

insert into public.muscles (
  code,
  display_name,
  display_name_ko,
  display_name_latin,
  anatomy_id,
  parent_muscle_code,
  side,
  display_order
)
select
  s.code,
  s.display_name,
  s.display_name_ko,
  s.display_name_latin,
  s.anatomy_id,
  s.parent_muscle_code,
  s.side,
  s.display_order
from tmp_standard_muscles s
on conflict (code) do update
set
  display_name = excluded.display_name,
  display_name_ko = excluded.display_name_ko,
  display_name_latin = excluded.display_name_latin,
  anatomy_id = excluded.anatomy_id,
  parent_muscle_code = excluded.parent_muscle_code,
  side = excluded.side,
  display_order = excluded.display_order,
  updated_at = now();

delete from public.muscles m
where public.is_placeholder_muscle_text(m.code)
   or public.is_placeholder_muscle_text(coalesce(m.display_name_ko, m.display_name, ''));

delete from public.muscles m
where not exists (
  select 1
  from tmp_standard_muscles s
  where s.code = m.code
);

update public.muscles
set display_name_ko = display_name
where display_name_ko is null;

alter table public.muscles
  alter column display_name_ko set not null;

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

create unique index if not exists idx_muscles_anatomy_id_unique
  on public.muscles (anatomy_id)
  where anatomy_id is not null;

create index if not exists idx_muscles_parent_muscle_code
  on public.muscles (parent_muscle_code);

-- -----------------------------------------------------------------------------
-- 2) Alias table for strict canonicalization
-- -----------------------------------------------------------------------------
create table if not exists public.muscle_code_aliases (
  alias_code text primary key check (alias_code ~ '^[a-z0-9_]+$'),
  muscle_code text not null references public.muscles(code) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_muscle_code_aliases_set_updated_at on public.muscle_code_aliases;
create trigger trg_muscle_code_aliases_set_updated_at
before update on public.muscle_code_aliases
for each row
execute function public.set_updated_at();

alter table public.muscle_code_aliases enable row level security;

drop policy if exists muscle_code_aliases_select_authenticated on public.muscle_code_aliases;
create policy muscle_code_aliases_select_authenticated
on public.muscle_code_aliases
for select
to authenticated
using (true);

insert into public.muscle_code_aliases (alias_code, muscle_code)
select
  v.alias_code,
  v.muscle_code
from (
  values
    -- canonical self aliases
    ('chest', 'chest'),
    ('upper_chest', 'upper_chest'),
    ('serratus_anterior', 'serratus_anterior'),
    ('shoulders', 'shoulders'),
    ('front_deltoid', 'front_deltoid'),
    ('lateral_deltoid', 'lateral_deltoid'),
    ('rear_deltoid', 'rear_deltoid'),
    ('traps', 'traps'),
    ('upper_trapezius', 'upper_trapezius'),
    ('middle_trapezius', 'middle_trapezius'),
    ('lower_trapezius', 'lower_trapezius'),
    ('lats', 'lats'),
    ('middle_back', 'middle_back'),
    ('rhomboids', 'rhomboids'),
    ('lower_back', 'lower_back'),
    ('spinal_erectors', 'spinal_erectors'),
    ('biceps', 'biceps'),
    ('triceps', 'triceps'),
    ('forearms', 'forearms'),
    ('forearm_flexors', 'forearm_flexors'),
    ('forearm_extensors', 'forearm_extensors'),
    ('abdominals', 'abdominals'),
    ('abs', 'abs'),
    ('transverse_abdominis', 'transverse_abdominis'),
    ('obliques', 'obliques'),
    ('hip_flexors', 'hip_flexors'),
    ('glutes', 'glutes'),
    ('abductors', 'abductors'),
    ('adductors', 'adductors'),
    ('quadriceps', 'quadriceps'),
    ('hamstrings', 'hamstrings'),
    ('calves', 'calves'),
    ('tibialis_anterior', 'tibialis_anterior'),
    ('neck', 'neck'),

    -- normalization aliases from imported JSON / legacy naming
    ('shoulder', 'shoulders'),
    ('deltoids', 'shoulders'),
    ('trapezius', 'traps'),
    ('middleback', 'middle_back'),
    ('lowerback', 'lower_back'),
    ('erector_spinae', 'spinal_erectors'),
    ('forearm', 'forearms'),
    ('rectus_abdominis', 'abs'),
    ('core', 'abdominals')
) as v(alias_code, muscle_code)
on conflict (alias_code) do update
set
  muscle_code = excluded.muscle_code,
  updated_at = now();

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

-- -----------------------------------------------------------------------------
-- 3) Canonicalize exercises arrays and rebuild bridge mapping
-- -----------------------------------------------------------------------------
update public.exercises e
set primary_muscles = coalesce(
  (
    select array_agg(distinct m.code order by m.code)
    from public.exercise_muscle_mapping emm
    join public.muscles m
      on m.id = emm.muscle_id
    where emm.exercise_id = e.id
      and emm.role = 'primary'
  ),
  e.primary_muscles
)
where coalesce(array_length(e.primary_muscles, 1), 0) = 0;

update public.exercises e
set secondary_muscles = coalesce(
  (
    select array_agg(distinct m.code order by m.code)
    from public.exercise_muscle_mapping emm
    join public.muscles m
      on m.id = emm.muscle_id
    where emm.exercise_id = e.id
      and emm.role = 'secondary'
  ),
  e.secondary_muscles
)
where coalesce(array_length(e.secondary_muscles, 1), 0) = 0;

update public.exercises e
set primary_muscles = coalesce(
  (
    select array_agg(distinct r.muscle_code order by r.muscle_code)
    from (
      select public.resolve_muscle_code(raw.code) as muscle_code
      from unnest(coalesce(e.primary_muscles, '{}'::text[])) as raw(code)
    ) r
    where r.muscle_code is not null
  ),
  '{}'::text[]
);

update public.exercises e
set secondary_muscles = coalesce(
  (
    select array_agg(distinct r.muscle_code order by r.muscle_code)
    from (
      select public.resolve_muscle_code(raw.code) as muscle_code
      from unnest(coalesce(e.secondary_muscles, '{}'::text[])) as raw(code)
    ) r
    where r.muscle_code is not null
  ),
  '{}'::text[]
);

delete from public.exercise_muscle_mapping;

with exploded as (
  select
    e.id as exercise_id,
    pm.code as muscle_code,
    'primary'::text as role,
    1 as priority
  from public.exercises e
  cross join lateral unnest(coalesce(e.primary_muscles, '{}'::text[])) as pm(code)
  union all
  select
    e.id as exercise_id,
    sm.code as muscle_code,
    'secondary'::text as role,
    2 as priority
  from public.exercises e
  cross join lateral unnest(coalesce(e.secondary_muscles, '{}'::text[])) as sm(code)
),
dedup as (
  select distinct on (x.exercise_id, x.muscle_code)
    x.exercise_id,
    x.muscle_code,
    x.role
  from exploded x
  where x.muscle_code is not null
  order by x.exercise_id, x.muscle_code, x.priority
)
insert into public.exercise_muscle_mapping (exercise_id, muscle_id, role)
select
  d.exercise_id,
  m.id as muscle_id,
  d.role
from dedup d
join public.muscles m
  on m.code = d.muscle_code;

-- -----------------------------------------------------------------------------
-- 4) Heatmap RPC contract hardening (no placeholder, no unknown code leak)
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

commit;
