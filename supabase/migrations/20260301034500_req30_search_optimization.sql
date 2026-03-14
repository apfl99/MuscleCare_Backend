-- REQ-30 search optimization for exercise lookup/autocomplete

begin;

create extension if not exists pg_trgm;

create index if not exists idx_exercises_name_trgm
  on public.exercises
  using gin (name gin_trgm_ops);

create or replace function public.search_exercises(p_keyword text)
returns table (
  id uuid,
  name text,
  category text
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
    e.category
  from public.exercises e
  cross join kw
  where kw.q <> ''
    and e.name ilike '%' || kw.q || '%'
  order by
    similarity(e.name, kw.q) desc,
    e.name asc
  limit 20;
$$;

revoke all on function public.search_exercises(text) from public;
grant execute on function public.search_exercises(text) to authenticated, service_role;

commit;
