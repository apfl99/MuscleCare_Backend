-- REQ-30 V1.0: align backend canonical muscles with frontend 3D detailed map (91 codes)

begin;

create temporary table tmp_detailed_muscles (
  code text primary key,
  display_name text not null,
  display_name_ko text not null,
  display_order integer not null
) on commit drop;

with detailed_codes as (
  select
    code,
    ordinality
  from unnest(
    array[
      'adductor_brevis','adductor_longus','adductor_magnus','adductor_minimus','anconeus',
      'biceps_brachii_long_head','biceps_brachii_short_head','biceps_femoris_long_head','biceps_femoris_short_head',
      'brachialis','brachioradialis','coracobrachialis','deltoid_anterior','deltoid_lateral','deltoid_posterior',
      'extensor_carpi_radialis_brevis','extensor_carpi_radialis_longus','extensor_carpi_ulnaris',
      'extensor_digiti_minimi','extensor_digitorum','external_oblique','flexor_carpi_radialis','flexor_carpi_ulnaris',
      'gastrocnemius_lateral_head','gastrocnemius_medial_head','gemellus_inferior','gemellus_superior',
      'gluteus_maximus','gluteus_medius','gluteus_minimus','gracilis','iliacus','iliocostalis_cervicis',
      'iliocostalis_lumborum','iliocostalis_thoracis','infraspinatus','internal_oblique','latissimus_dorsi',
      'levator_scapulae','longissimus_thoracis','multifidus','palmaris_longus','pectineus',
      'pectoralis_major_abdominal','pectoralis_major_clavicular','pectoralis_major_sternocostal','pectoralis_minor',
      'piriformis','plantaris','pronator_teres_deep','pronator_teres_superficial','psoas_major',
      'quadratus_femoris','quadratus_lumborum','rectus_abdominis','rectus_femoris','rhomboid_major','rhomboid_minor',
      'sartorius','semimembranosus','semispinalis_cervicis','semispinalis_thoracis','semitendinosus',
      'serratus_anterior','serratus_posterior_inferior','serratus_posterior_superior','soleus',
      'spinalis_capitis','spinalis_cervicis','spinalis_thoracis','splenius_capitis','splenius_cervicis',
      'sternocleidomastoid','subclavius','subscapularis','supinator','supraspinatus','teres_major','teres_minor',
      'tibialis_anterior','tibialis_posterior','transversus_abdominis','trapezius_ascending','trapezius_descending',
      'trapezius_transverse','triceps_brachii_lateral_head','triceps_brachii_long_head','triceps_brachii_medial_head',
      'vastus_intermedius','vastus_lateralis','vastus_medialis'
    ]::text[]
  ) with ordinality as t(code, ordinality)
)
insert into tmp_detailed_muscles (code, display_name, display_name_ko, display_order)
select
  dc.code,
  initcap(replace(dc.code, '_', ' ')) as display_name,
  initcap(replace(dc.code, '_', ' ')) as display_name_ko,
  (dc.ordinality * 10)::integer as display_order
from detailed_codes dc;

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
  tdm.code,
  tdm.display_name,
  tdm.display_name_ko,
  null,
  null,
  null,
  'bilateral',
  tdm.display_order
from tmp_detailed_muscles tdm
on conflict (code) do update
set
  display_name = excluded.display_name,
  display_name_ko = excluded.display_name_ko,
  display_name_latin = excluded.display_name_latin,
  parent_muscle_code = excluded.parent_muscle_code,
  side = excluded.side,
  display_order = excluded.display_order,
  updated_at = now();

delete from public.muscles m
where not exists (
  select 1
  from tmp_detailed_muscles tdm
  where tdm.code = m.code
);

insert into public.muscle_code_aliases (alias_code, muscle_code)
select
  tdm.code as alias_code,
  tdm.code as muscle_code
from tmp_detailed_muscles tdm
on conflict (alias_code) do update
set
  muscle_code = excluded.muscle_code,
  updated_at = now();

insert into public.muscle_code_aliases (alias_code, muscle_code)
values
  ('chest', 'pectoralis_major_sternocostal'),
  ('pecs', 'pectoralis_major_sternocostal'),
  ('pectorals', 'pectoralis_major_sternocostal'),
  ('front_deltoid', 'deltoid_anterior'),
  ('lateral_deltoid', 'deltoid_lateral'),
  ('rear_deltoid', 'deltoid_posterior'),
  ('trapezius', 'trapezius_descending'),
  ('traps', 'trapezius_descending'),
  ('rhomboids', 'rhomboid_major'),
  ('lats', 'latissimus_dorsi'),
  ('latissimus', 'latissimus_dorsi'),
  ('biceps', 'biceps_brachii_long_head'),
  ('triceps', 'triceps_brachii_long_head'),
  ('forearm_flexor', 'flexor_carpi_radialis'),
  ('forearm_extensor', 'extensor_carpi_radialis_longus'),
  ('abs', 'rectus_abdominis'),
  ('abdominals', 'rectus_abdominis'),
  ('core', 'rectus_abdominis'),
  ('obliques', 'external_oblique'),
  ('glutes', 'gluteus_maximus'),
  ('abductors', 'gluteus_medius'),
  ('adductors', 'adductor_longus'),
  ('quadriceps', 'rectus_femoris'),
  ('quads', 'rectus_femoris'),
  ('hamstrings', 'biceps_femoris_long_head'),
  ('calves', 'gastrocnemius_medial_head'),
  ('calf', 'gastrocnemius_medial_head'),
  ('gastrocnemius', 'gastrocnemius_medial_head'),
  ('tibialis_anterior', 'tibialis_anterior'),
  ('tibialis_posterior', 'tibialis_posterior'),
  ('neck', 'sternocleidomastoid')
on conflict (alias_code) do update
set
  muscle_code = excluded.muscle_code,
  updated_at = now();

update public.exercises e
set primary_muscles = coalesce(
  (
    select array_agg(distinct public.resolve_muscle_code(raw.code) order by public.resolve_muscle_code(raw.code))
    from unnest(coalesce(e.primary_muscles, '{}'::text[])) as raw(code)
    where public.resolve_muscle_code(raw.code) is not null
  ),
  '{}'::text[]
);

update public.exercises e
set secondary_muscles = coalesce(
  (
    select array_agg(distinct public.resolve_muscle_code(raw.code) order by public.resolve_muscle_code(raw.code))
    from unnest(coalesce(e.secondary_muscles, '{}'::text[])) as raw(code)
    where public.resolve_muscle_code(raw.code) is not null
  ),
  '{}'::text[]
);

update public.exercises e
set secondary_muscles = coalesce(
  (
    select array_agg(code order by code)
    from (
      select distinct s.code
      from unnest(coalesce(e.secondary_muscles, '{}'::text[])) as s(code)
      where s.code <> all(coalesce(e.primary_muscles, '{}'::text[]))
    ) dedup
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

commit;
