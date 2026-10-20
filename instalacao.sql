-- =====================================================================
-- F2 Conect · instalação do banco no Supabase
-- Rode UMA vez: Supabase → SQL Editor → New query → cole tudo → Run.
-- Pode rodar de novo sem perder dados (comandos idempotentes).
-- =====================================================================

-- 1. Perfis de acesso (um por usuário do Supabase Auth)
create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  nome text,
  perfil text not null default 'pendente',   -- admin | operacional | financeiro | gestor | condutor | pendente
  cliente_id text,                           -- para gestor e condutor
  condutor_id text,                          -- para condutor
  ativo boolean not null default false,
  criado_em timestamptz not null default now(),
  ultimo_acesso timestamptz
);

-- 2. Registros do sistema (veículos, contratos, usos, faturas...)
create table if not exists public.registros (
  colecao text not null,
  id text not null,
  dados jsonb not null,
  cliente_id text,                 -- define quem do lado do cliente pode ver
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid(),
  primary key (colecao, id)
);
create index if not exists registros_cliente_idx on public.registros (cliente_id);
create index if not exists registros_colecao_idx on public.registros (colecao);
-- No máximo um check-in aberto por veículo, garantido pelo banco
create unique index if not exists uso_aberto_unico on public.registros ((dados->>'veiculoId'))
  where colecao = 'usos' and dados->>'status' = 'em_uso' and coalesce(dados->>'excluido','false') <> 'true';
alter table public.registros replica identity full;

-- 3. Funções de apoio às regras de acesso
create or replace function public.f2_perfil() returns text
  language sql stable security definer set search_path = public as
$$ select case when ativo then perfil else 'inativo' end from perfis where id = auth.uid() $$;

create or replace function public.f2_cliente() returns text
  language sql stable security definer set search_path = public as
$$ select cliente_id from perfis where id = auth.uid() and ativo $$;

create or replace function public.f2_equipe() returns boolean
  language sql stable security definer set search_path = public as
$$ select coalesce((select ativo and perfil in ('admin','operacional','financeiro') from perfis where id = auth.uid()), false) $$;

create or replace function public.f2_registrar_acesso() returns void
  language sql security definer set search_path = public as
$$ update perfis set ultimo_acesso = now() where id = auth.uid() $$;

create sequence if not exists public.f2_chamado_seq;
create or replace function public.f2_proximo_chamado() returns bigint
  language sql security definer set search_path = public as
$$ select nextval('f2_chamado_seq') $$;

-- 4. Novo usuário: o primeiro vira administrador; os demais ficam pendentes
create or replace function public.f2_novo_usuario() returns trigger
  language plpgsql security definer set search_path = public as
$$
declare primeiro boolean;
begin
  select not exists (select 1 from perfis) into primeiro;
  insert into perfis (id, email, nome, perfil, ativo)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nome', new.email),
          case when primeiro then 'admin' else 'pendente' end, primeiro)
  on conflict (id) do nothing;
  return new;
end
$$;
drop trigger if exists f2_on_auth_user on auth.users;
create trigger f2_on_auth_user after insert on auth.users
  for each row execute function public.f2_novo_usuario();

-- 5. Regras de acesso (Row Level Security)
alter table public.perfis enable row level security;
alter table public.registros enable row level security;

drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated
  using (id = auth.uid() or public.f2_equipe());
drop policy if exists perfis_admin on public.perfis;
create policy perfis_admin on public.perfis for update to authenticated
  using (public.f2_perfil() = 'admin') with check (public.f2_perfil() = 'admin');

-- Equipe F2 (admin, operacional, financeiro): acesso completo
drop policy if exists reg_equipe on public.registros;
create policy reg_equipe on public.registros for all to authenticated
  using (public.f2_equipe()) with check (public.f2_equipe());

-- Cliente (gestor e condutor): só os registros do próprio cliente; nunca financeiro interno nem auditoria
drop policy if exists reg_cliente_ler on public.registros;
create policy reg_cliente_ler on public.registros for select to authenticated
  using (colecao = 'config'
         or (cliente_id is not null and cliente_id = public.f2_cliente()
             and colecao not in ('lancamentos','auditoria')));

drop policy if exists reg_cliente_inserir on public.registros;
create policy reg_cliente_inserir on public.registros for insert to authenticated
  with check (cliente_id = public.f2_cliente()
              and colecao in ('chamados','reembolsos','leituras','usos','pacotes','condutores','manutencoes','auditoria'));

drop policy if exists reg_cliente_alterar on public.registros;
create policy reg_cliente_alterar on public.registros for update to authenticated
  using (cliente_id = public.f2_cliente()
         and colecao in ('usos','vistorias','multas','condutores','chamados','reembolsos'))
  with check (cliente_id = public.f2_cliente()
         and colecao in ('usos','vistorias','multas','condutores','chamados','reembolsos'));

-- 6. Tempo real
do $$ begin
  alter publication supabase_realtime add table public.registros;
exception when duplicate_object then null; end $$;

-- 7. Anexos (Storage): pasta f2/ só da equipe; pasta cliente_<id>/ também do próprio cliente
insert into storage.buckets (id, name, public) values ('anexos', 'anexos', false)
  on conflict (id) do nothing;

drop policy if exists anexos_equipe on storage.objects;
create policy anexos_equipe on storage.objects for all to authenticated
  using (bucket_id = 'anexos' and public.f2_equipe())
  with check (bucket_id = 'anexos' and public.f2_equipe());
drop policy if exists anexos_cliente_ler on storage.objects;
create policy anexos_cliente_ler on storage.objects for select to authenticated
  using (bucket_id = 'anexos' and (storage.foldername(name))[1] = 'cliente_' || public.f2_cliente());
drop policy if exists anexos_cliente_enviar on storage.objects;
create policy anexos_cliente_enviar on storage.objects for insert to authenticated
  with check (bucket_id = 'anexos' and (storage.foldername(name))[1] = 'cliente_' || public.f2_cliente());

-- Fim. Depois: Authentication → URL Configuration → Site URL = endereço do site no Vercel.
