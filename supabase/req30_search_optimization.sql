-- REQ-30 search optimization (Korean, chosung, synonyms)

begin;

create extension if not exists pg_trgm;

alter table public.exercises
  add column if not exists primary_muscles text[] not null default '{}'::text[],
  add column if not exists secondary_muscles text[] not null default '{}'::text[],
  add column if not exists biomechanics_note text;

create or replace function public.search_normalize_text(p_text text)
returns text
language sql
immutable
parallel safe
as $$
  select regexp_replace(
    lower(trim(coalesce(p_text, ''))),
    '[^a-z0-9가-힣ㄱ-ㅎ]+',
    '',
    'g'
  );
$$;

create or replace function public.hangul_to_choseong(p_text text)
returns text
language sql
immutable
parallel safe
as $$
  with src as (
    select lower(trim(coalesce(p_text, ''))) as v
  ),
  r1 as (select regexp_replace(v, '[가-깋]', 'ㄱ', 'g') as v from src),
  r2 as (select regexp_replace(v, '[까-낗]', 'ㄲ', 'g') as v from r1),
  r3 as (select regexp_replace(v, '[나-닣]', 'ㄴ', 'g') as v from r2),
  r4 as (select regexp_replace(v, '[다-딯]', 'ㄷ', 'g') as v from r3),
  r5 as (select regexp_replace(v, '[따-띻]', 'ㄸ', 'g') as v from r4),
  r6 as (select regexp_replace(v, '[라-맇]', 'ㄹ', 'g') as v from r5),
  r7 as (select regexp_replace(v, '[마-밓]', 'ㅁ', 'g') as v from r6),
  r8 as (select regexp_replace(v, '[바-빟]', 'ㅂ', 'g') as v from r7),
  r9 as (select regexp_replace(v, '[빠-삫]', 'ㅃ', 'g') as v from r8),
  r10 as (select regexp_replace(v, '[사-싷]', 'ㅅ', 'g') as v from r9),
  r11 as (select regexp_replace(v, '[싸-앃]', 'ㅆ', 'g') as v from r10),
  r12 as (select regexp_replace(v, '[아-잏]', 'ㅇ', 'g') as v from r11),
  r13 as (select regexp_replace(v, '[자-짛]', 'ㅈ', 'g') as v from r12),
  r14 as (select regexp_replace(v, '[짜-찧]', 'ㅉ', 'g') as v from r13),
  r15 as (select regexp_replace(v, '[차-칳]', 'ㅊ', 'g') as v from r14),
  r16 as (select regexp_replace(v, '[카-킿]', 'ㅋ', 'g') as v from r15),
  r17 as (select regexp_replace(v, '[타-팋]', 'ㅌ', 'g') as v from r16),
  r18 as (select regexp_replace(v, '[파-핗]', 'ㅍ', 'g') as v from r17),
  r19 as (select regexp_replace(v, '[하-힣]', 'ㅎ', 'g') as v from r18)
  select regexp_replace(v, '[^ㄱ-ㅎa-z0-9]+', '', 'g')
  from r19;
$$;

create table if not exists public.exercise_search_aliases (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  alias text not null check (length(trim(alias)) > 0),
  alias_type text not null default 'synonym'
    check (alias_type in ('ko', 'synonym', 'abbr', 'keyword')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_id, alias)
);

drop trigger if exists trg_exercise_search_aliases_set_updated_at on public.exercise_search_aliases;
create trigger trg_exercise_search_aliases_set_updated_at
before update on public.exercise_search_aliases
for each row
execute function public.set_updated_at();

alter table public.exercise_search_aliases enable row level security;
drop policy if exists exercise_search_aliases_select_authenticated on public.exercise_search_aliases;
create policy exercise_search_aliases_select_authenticated
on public.exercise_search_aliases
for select
to authenticated
using (true);

create index if not exists idx_exercises_name_trgm
  on public.exercises
  using gin (name gin_trgm_ops);

create index if not exists idx_exercises_primary_muscles_gin
  on public.exercises using gin (primary_muscles);

create index if not exists idx_exercises_secondary_muscles_gin
  on public.exercises using gin (secondary_muscles);

create index if not exists idx_exercises_name_norm_trgm
  on public.exercises
  using gin ((public.search_normalize_text(name)) gin_trgm_ops);

create index if not exists idx_exercise_aliases_alias_trgm
  on public.exercise_search_aliases
  using gin (alias gin_trgm_ops);

create index if not exists idx_exercise_aliases_alias_norm_trgm
  on public.exercise_search_aliases
  using gin ((public.search_normalize_text(alias)) gin_trgm_ops);

create index if not exists idx_exercise_aliases_alias_choseong_trgm
  on public.exercise_search_aliases
  using gin ((public.hangul_to_choseong(alias)) gin_trgm_ops);

with alias_seed as (
  select *
  from (
    values
      ('back_squat', '스쿼트', 'keyword'),
      ('back_squat', '백 스쿼트', 'ko'),
      ('back_squat', '백스쿼트', 'synonym'),
      ('back_squat', '바벨 스쿼트', 'synonym'),
      ('front_squat', '프론트 스쿼트', 'ko'),
      ('front_squat', '프론트스쿼트', 'synonym'),
      ('goblet_squat', '고블릿 스쿼트', 'ko'),
      ('goblet_squat', '고블릿스쿼트', 'synonym'),
      ('hack_squat', '핵 스쿼트', 'ko'),
      ('hack_squat', '핵스쿼트', 'synonym'),
      ('machine_hack_squat', '머신 핵 스쿼트', 'ko'),
      ('machine_hack_squat', '머신핵스쿼트', 'synonym'),
      ('smith_machine_squat', '스미스 스쿼트', 'ko'),
      ('smith_machine_squat', '스미스머신 스쿼트', 'synonym'),
      ('safety_bar_squat', '세이프티 바 스쿼트', 'ko'),
      ('safety_bar_squat', '세이프티바 스쿼트', 'synonym'),
      ('zercher_squat', '저처 스쿼트', 'ko'),
      ('high_bar_back_squat', '하이바 백 스쿼트', 'ko'),
      ('low_bar_back_squat', '로우바 백 스쿼트', 'ko'),
      ('bulgarian_split_squat', '불가리안 스플릿 스쿼트', 'ko'),
      ('dumbbell_split_squat', '덤벨 스플릿 스쿼트', 'ko'),
      ('leg_press', '레그 프레스', 'ko'),
      ('leg_press', '레그프레스', 'synonym'),
      ('leg_extension', '레그 익스텐션', 'ko'),
      ('leg_extension', '레그익스텐션', 'synonym'),
      ('seated_leg_curl', '시티드 레그 컬', 'ko'),
      ('seated_leg_curl', '시티드레그컬', 'synonym'),
      ('lying_leg_curl', '라잉 레그 컬', 'ko'),
      ('lying_leg_curl', '라잉레그컬', 'synonym'),
      ('standing_leg_curl', '스탠딩 레그 컬', 'ko'),
      ('dumbbell_walking_lunge', '워킹 런지', 'keyword'),
      ('dumbbell_walking_lunge', '덤벨 워킹 런지', 'ko'),
      ('reverse_lunge', '리버스 런지', 'ko'),
      ('curtsy_lunge', '커시 런지', 'ko'),
      ('step_up', '스텝 업', 'ko'),
      ('step_up', '스텝업', 'synonym'),

      ('conventional_deadlift', '데드리프트', 'keyword'),
      ('conventional_deadlift', '컨벤셔널 데드리프트', 'ko'),
      ('sumo_deadlift', '스모 데드리프트', 'ko'),
      ('sumo_deadlift', '스모데드리프트', 'synonym'),
      ('romanian_deadlift', '루마니안 데드리프트', 'ko'),
      ('romanian_deadlift', '루마니안데드리프트', 'synonym'),
      ('romanian_deadlift', 'rdl', 'abbr'),
      ('trap_bar_deadlift', '트랩바 데드리프트', 'ko'),
      ('rack_pull', '랙 풀', 'ko'),
      ('good_morning', '굿모닝', 'ko'),
      ('barbell_hip_thrust', '힙 쓰러스트', 'keyword'),
      ('barbell_hip_thrust', '바벨 힙쓰러스트', 'ko'),
      ('barbell_hip_thrust', '힙쓰러스트', 'synonym'),
      ('smith_machine_hip_thrust', '스미스 힙쓰러스트', 'ko'),
      ('glute_bridge', '글루트 브리지', 'ko'),
      ('glute_bridge', '글루트브리지', 'synonym'),

      ('barbell_flat_bench_press', '벤치프레스', 'keyword'),
      ('barbell_flat_bench_press', '벤치 프레스', 'synonym'),
      ('barbell_flat_bench_press', '바벨 벤치 프레스', 'ko'),
      ('barbell_incline_bench_press', '인클라인 벤치 프레스', 'ko'),
      ('barbell_incline_bench_press', '인클라인벤치프레스', 'synonym'),
      ('barbell_decline_bench_press', '디클라인 벤치 프레스', 'ko'),
      ('dumbbell_flat_bench_press', '덤벨 벤치 프레스', 'ko'),
      ('dumbbell_flat_bench_press', '덤벨벤치프레스', 'synonym'),
      ('dumbbell_incline_bench_press', '덤벨 인클라인 벤치 프레스', 'ko'),
      ('machine_chest_press', '체스트 프레스', 'ko'),
      ('machine_chest_press', '머신 체스트 프레스', 'synonym'),
      ('incline_machine_chest_press', '인클라인 체스트 프레스', 'ko'),
      ('cable_crossover', '케이블 크로스오버', 'ko'),
      ('cable_crossover', '케이블크로스오버', 'synonym'),
      ('pec_deck_fly', '펙덱 플라이', 'ko'),
      ('close_grip_bench_press', '클로즈그립 벤치프레스', 'ko'),

      ('standing_barbell_overhead_press', '오버헤드 프레스', 'ko'),
      ('standing_barbell_overhead_press', '밀리터리 프레스', 'synonym'),
      ('standing_barbell_overhead_press', '밀프', 'abbr'),
      ('standing_dumbbell_overhead_press', '덤벨 오버헤드 프레스', 'ko'),
      ('push_press', '푸시 프레스', 'ko'),
      ('push_press', '푸시프레스', 'synonym'),
      ('arnold_press', '아놀드 프레스', 'ko'),

      ('pull_up', '풀업', 'ko'),
      ('chin_up', '친업', 'ko'),
      ('lat_pulldown', '랫 풀다운', 'ko'),
      ('lat_pulldown', '랫풀다운', 'synonym'),
      ('barbell_bent_over_row', '바벨 로우', 'keyword'),
      ('barbell_bent_over_row', '벤트오버 로우', 'ko'),
      ('barbell_bent_over_row', '바벨 벤트오버 로우', 'synonym'),
      ('seated_cable_row', '시티드 케이블 로우', 'ko'),
      ('seated_cable_row', '시티드케이블로우', 'synonym'),
      ('dumbbell_single_arm_row', '원암 덤벨 로우', 'ko'),
      ('dumbbell_single_arm_row', '원암덤벨로우', 'synonym'),
      ('t_bar_row', '티바 로우', 'ko'),
      ('t_bar_row', '티바로우', 'synonym'),
      ('face_pull', '페이스 풀', 'ko'),

      ('barbell_biceps_curl', '바벨 컬', 'ko'),
      ('barbell_biceps_curl', '이두 컬', 'synonym'),
      ('dumbbell_hammer_curl', '해머 컬', 'ko'),
      ('dumbbell_hammer_curl', '해머컬', 'synonym'),
      ('cable_biceps_curl', '케이블 컬', 'ko'),
      ('cable_triceps_pushdown', '삼두 푸시다운', 'keyword'),
      ('cable_triceps_pushdown', '트라이셉스 푸시다운', 'ko'),
      ('cable_triceps_pushdown', '푸시다운', 'synonym'),
      ('rope_triceps_pushdown', '로프 푸시다운', 'ko'),
      ('skullcrusher', '스컬크러셔', 'ko'),
      ('overhead_cable_triceps_extension', '오버헤드 트라이셉스 익스텐션', 'ko'),

      ('seated_calf_raise', '시티드 카프 레이즈', 'ko'),
      ('standing_calf_raise', '스탠딩 카프 레이즈', 'ko'),
      ('burpee', '버피', 'ko'),
      ('mountain_climber', '마운틴 클라이머', 'ko'),
      ('plank', '플랭크', 'ko'),
      ('ab_wheel_rollout', '앱 휠', 'keyword'),
      ('ab_wheel_rollout', '아브휠', 'synonym'),
      ('russian_twist', '러시안 트위스트', 'ko'),
      ('cable_woodchop', '우드찹', 'keyword'),
      ('cable_woodchop', '우드 촙', 'synonym'),
      ('farmer_carry', '파머 캐리', 'ko'),
      ('farmer_carry', '파머캐리', 'synonym'),
      ('sled_push', '슬레드 푸시', 'ko'),
      ('sled_push', '슬레드푸시', 'synonym'),
      ('rope_climb', '로프 클라임', 'ko'),
      ('jump_rope_double_under', '더블 언더', 'ko'),
      ('jump_rope_double_under', '더블언더', 'synonym')
  ) as t(slug, alias, alias_type)
),
resolved as (
  select
    e.id as exercise_id,
    s.alias,
    s.alias_type
  from alias_seed s
  join public.exercises e
    on e.slug = s.slug
)
insert into public.exercise_search_aliases (exercise_id, alias, alias_type)
select
  r.exercise_id,
  r.alias,
  r.alias_type
from resolved r
on conflict (exercise_id, alias) do update
set
  alias_type = excluded.alias_type,
  updated_at = now();

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

commit;
