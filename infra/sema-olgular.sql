-- SEMA OLGULARI — sira-duyarsiz sema karsilastirmasi icin (tur: prod uyum).
--
-- `infra/goc-uyum-dogrula.sh` bunu iki veritabaninda kosturup ciktilari
-- siralayip diff'ler. Ayri dosyada durmasinin sebebi: elle kontrol yaparken de
-- AYNI sorgunun kullanilabilmesi. (Sorguyu betikten regex'le cikarmaya
-- calismak bir kez 0 olgu dondurup karsilastirmayi BOSA GECIRDI.)
--
-- `:app_rol` psql degiskeni ile cagrilir:
--   psql -d <db> -Atc "\set app_rol app_rw" -f sema-olgular.sql
-- ya da betikteki gibi -v app_rol=... ile.
select 'TABLO '||c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and c.relname<>'alembic_version'
union all
select 'KOLON '||table_name||'.'||column_name||' :: '||udt_name||' null='||is_nullable
       ||' def='||coalesce(column_default,'-')
  from information_schema.columns where table_schema='public'
    and table_name<>'alembic_version'
union all
select 'KISIT '||co.conrelid::regclass::text||' '||co.conname||' '||pg_get_constraintdef(co.oid)
  from pg_constraint co join pg_namespace n on n.oid=co.connamespace where n.nspname='public'
union all
select 'INDEKS '||indexdef from pg_indexes where schemaname='public'
  and tablename<>'alembic_version'
union all
select 'ENUM '||t.typname||' = '||string_agg(e.enumlabel,',' order by e.enumsortorder)
  from pg_type t join pg_enum e on e.enumtypid=t.oid
  join pg_namespace n on n.oid=t.typnamespace where n.nspname='public'
  group by t.typname
union all
select 'RLS '||c.relname||' enable='||c.relrowsecurity::text||' force='||c.relforcerowsecurity::text
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and c.relname<>'alembic_version'
union all
select 'POLITIKA '||c.relname||' '||p.polname||' cmd='||p.polcmd::text
       ||' using='||coalesce(pg_get_expr(p.polqual,p.polrelid),'-')
       ||' check='||coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'-')
  from pg_policy p join pg_class c on c.oid=p.polrelid
  join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
union all
select 'FONKSIYON '||p.proname||'('||pg_get_function_arguments(p.oid)||') secdef='
       ||p.prosecdef::text||' cfg='||coalesce(array_to_string(p.proconfig,','),'-')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
union all
select 'YETKI '||table_name||' '||privilege_type from information_schema.table_privileges
  where table_schema='public' and grantee=:'app_rol'
union all
select 'GORUNUM '||viewname from pg_views where schemaname='public'
