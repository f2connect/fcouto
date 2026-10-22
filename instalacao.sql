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
create or replace function public.f2_condutor_id() returns text
  language sql stable security definer set search_path = public as
$$ select condutor_id from perfis where id = auth.uid() and ativo and perfil = 'condutor' $$;

-- Leitura do lado do cliente:
--   gestor (administrativo do cliente): tudo da própria empresa, menos o financeiro interno e a auditoria da F2;
--   motorista: só carros, uso, km, abastecimento, vistorias, chamados e manutenções, e o próprio cadastro.
--   Contratos, valores, faturas, pacotes, multas, documentos e dados de outros motoristas ficam fora.
--   Modelos de plano (preços) são só da F2. Compra, consórcio e venda dos carros ficam em veiculos_fin, só da F2.
drop policy if exists reg_cliente_ler on public.registros;
create policy reg_cliente_ler on public.registros for select to authenticated
  using ((colecao = 'config' and id <> 'planos')
         or (cliente_id is not null and cliente_id = public.f2_cliente()
             and colecao not in ('lancamentos','auditoria','veiculos_fin')
             and (public.f2_perfil() = 'gestor'
                  or colecao in ('veiculos','usos','leituras','abastecimentos','vistorias','chamados','manutencoes')
                  or (colecao = 'condutores' and id = public.f2_condutor_id()))));

drop policy if exists reg_cliente_inserir on public.registros;
create policy reg_cliente_inserir on public.registros for insert to authenticated
  with check (cliente_id = public.f2_cliente() and (
    (public.f2_perfil() = 'gestor' and colecao in ('chamados','reembolsos','leituras','usos','pacotes','condutores','manutencoes','auditoria','abastecimentos','vistorias'))
    or (public.f2_perfil() = 'condutor' and colecao in ('chamados','leituras','usos','auditoria','abastecimentos','vistorias'))));

drop policy if exists reg_cliente_alterar on public.registros;
create policy reg_cliente_alterar on public.registros for update to authenticated
  using (cliente_id = public.f2_cliente() and (
    (public.f2_perfil() = 'gestor' and colecao in ('usos','vistorias','multas','condutores','chamados','reembolsos','abastecimentos'))
    or (public.f2_perfil() = 'condutor' and (colecao in ('usos','abastecimentos') or (colecao = 'condutores' and id = public.f2_condutor_id())))))
  with check (cliente_id = public.f2_cliente() and (
    (public.f2_perfil() = 'gestor' and colecao in ('usos','vistorias','multas','condutores','chamados','reembolsos','abastecimentos'))
    or (public.f2_perfil() = 'condutor' and (colecao in ('usos','abastecimentos') or (colecao = 'condutores' and id = public.f2_condutor_id())))));

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

-- 8. Versão 2 · hora do servidor no check-in e checkout
create or replace function public.f2_hora_servidor() returns trigger
  language plpgsql set search_path = public as
$$
declare t text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM-DD"T"HH24:MI');
begin
  if new.colecao = 'usos' then
    if tg_op = 'INSERT' then
      if new.dados->>'status' = 'em_uso' and coalesce(new.dados->>'retroativo','false') <> 'true' then
        new.dados := new.dados || jsonb_build_object('inicio', t, 'inicioServidor', true);
      end if;
    else
      if coalesce(old.dados->>'inicioServidor','false') = 'true' then
        new.dados := new.dados || jsonb_build_object('inicio', old.dados->'inicio', 'inicioServidor', true);
      end if;
      if coalesce(old.dados->>'fimServidor','false') = 'true' then
        new.dados := new.dados || jsonb_build_object('fim', old.dados->'fim', 'fimServidor', true);
      elsif old.dados->>'status' = 'em_uso' and new.dados->>'status' in ('encerrado','encerrado_forcado') then
        new.dados := new.dados || jsonb_build_object('fim', t, 'fimServidor', true);
      end if;
    end if;
  elsif new.colecao = 'leituras' and tg_op = 'INSERT' and coalesce(new.dados->>'horaServidor','false') = 'true' then
    new.dados := new.dados || jsonb_build_object('data', t);
  end if;
  return new;
end
$$;
drop trigger if exists f2_hora on public.registros;
create trigger f2_hora before insert or update on public.registros
  for each row execute function public.f2_hora_servidor();

-- 9. Versão 2 · motoristas: vínculo pelo e-mail, cadastro pelo QR do carro e liberação pelo gestor
drop policy if exists perfis_gestor_ler on public.perfis;
create policy perfis_gestor_ler on public.perfis for select to authenticated
  using (public.f2_perfil() = 'gestor' and cliente_id = public.f2_cliente());

-- Conta nova com o mesmo e-mail de um motorista já cadastrado: liga os dois (o acesso só abre quando o gestor liberar)
create or replace function public.f2_vincular() returns boolean
  language plpgsql security definer set search_path = public as
$$
declare me perfis; c registros;
begin
  select * into me from perfis where id = auth.uid();
  if me.id is null or me.ativo or me.perfil <> 'pendente' or me.email is null then return false; end if;
  select * into c from registros
   where colecao = 'condutores' and lower(dados->>'email') = lower(me.email)
     and coalesce(dados->>'excluido','false') <> 'true' and coalesce(dados->>'status','') <> 'bloqueado'
   order by atualizado_em desc limit 1;
  if c.id is null then return false; end if;
  update perfis set perfil = 'condutor', cliente_id = coalesce(c.cliente_id, c.dados->>'clienteId'), condutor_id = c.id, ativo = false
   where id = me.id;
  return true;
end
$$;

-- Motorista leu o QR do carro e preencheu os dados: cria o cadastro pendente no cliente que está com o carro
create or replace function public.f2_cadastro_condutor(p_veiculo text, p_dados jsonb) returns text
  language plpgsql security definer set search_path = public as
$$
declare me perfis; cli text; cid text; hj text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM-DD');
begin
  select * into me from perfis where id = auth.uid();
  if me.id is null then raise exception 'Sessão inválida. Entre de novo.'; end if;
  if me.ativo then raise exception 'Seu acesso já está liberado. Recarregue a página.'; end if;
  if me.perfil not in ('pendente','condutor') then raise exception 'Este perfil não pode fazer cadastro de motorista.'; end if;
  select coalesce(cliente_id, dados->>'clienteId') into cli from registros
   where colecao = 'contratos' and dados->>'veiculoId' = p_veiculo
     and coalesce(dados->>'excluido','false') <> 'true' and coalesce(dados->>'status','ativo') <> 'encerrado'
     and dados->>'inicio' <= hj and (coalesce(dados->>'fim','') = '' or dados->>'fim' >= hj)
   order by dados->>'inicio' desc limit 1;
  if cli is null then raise exception 'Este carro não está com contrato ativo. Fale com o gestor da sua empresa.'; end if;
  if me.cliente_id is not null and me.cliente_id <> cli then raise exception 'Sua conta já está ligada a outra empresa.'; end if;
  cid := coalesce(me.condutor_id, 'auto' || substr(md5(me.id::text), 1, 12));
  insert into registros (colecao, id, dados, cliente_id, atualizado_em, atualizado_por)
  values ('condutores', cid, jsonb_build_object(
      'clienteId', cli, 'nome', left(coalesce(nullif(trim(p_dados->>'nome'),''), me.nome), 120),
      'cpf', left(p_dados->>'cpf', 20), 'telefone', left(p_dados->>'telefone', 30), 'cnh', left(p_dados->>'cnh', 30),
      'cnhValidade', left(p_dados->>'cnhValidade', 10), 'email', me.email, 'status', 'pendente', 'autoCadastro', true,
      'usuarioId', me.id, 'consentimentoLGPD', coalesce(p_dados->>'consentimento','') = 'true',
      'criadoEm', now(), 'criadoPor', me.id, 'atualizadoEm', now(), 'atualizadoPor', me.id), cli, now(), me.id)
  on conflict (colecao, id) do update
    set dados = registros.dados || (excluded.dados - 'status' - 'criadoEm' - 'criadoPor'), atualizado_em = now();
  update perfis set perfil = 'condutor', cliente_id = cli, condutor_id = cid,
         nome = coalesce(nullif(trim(p_dados->>'nome'),''), nome)
   where id = me.id;
  return cid;
end
$$;

-- Gestor do cliente (ou a F2) libera ou bloqueia o motorista e o acesso dele ao app
create or replace function public.f2_aprovar_condutor(p_condutor text, p_aprovar boolean) returns integer
  language plpgsql security definer set search_path = public as
$$
declare c registros; n integer;
begin
  select * into c from registros where colecao = 'condutores' and id = p_condutor;
  if c.id is null then raise exception 'Motorista não encontrado.'; end if;
  if not (public.f2_equipe() or (public.f2_perfil() = 'gestor' and public.f2_cliente() = c.cliente_id)) then
    raise exception 'Sem permissão para liberar este motorista.';
  end if;
  update registros set dados = dados || jsonb_build_object('status', case when p_aprovar then 'aprovado' else 'bloqueado' end,
           'atualizadoEm', now(), 'atualizadoPor', auth.uid(), 'liberadoPor', case when p_aprovar then auth.uid() end),
         atualizado_em = now(), atualizado_por = auth.uid()
   where colecao = 'condutores' and id = p_condutor;
  update perfis set perfil = 'condutor', cliente_id = c.cliente_id, condutor_id = p_condutor, ativo = p_aprovar
   where perfil in ('pendente','condutor')
     and (condutor_id = p_condutor
          or (condutor_id is null and lower(email) = lower(c.dados->>'email') and (cliente_id is null or cliente_id = c.cliente_id)));
  get diagnostics n = row_count;
  return n;
end
$$;

revoke execute on function public.f2_vincular() from anon;
revoke execute on function public.f2_cadastro_condutor(text, jsonb) from anon;
revoke execute on function public.f2_aprovar_condutor(text, boolean) from anon;

-- 10. Versão 6 · o administrativo do cliente também pode registrar sugestões de melhoria (pelo assistente)
drop policy if exists reg_cliente_inserir on public.registros;
create policy reg_cliente_inserir on public.registros for insert to authenticated
  with check (cliente_id = public.f2_cliente() and (
    (public.f2_perfil() = 'gestor' and colecao in ('chamados','reembolsos','leituras','usos','pacotes','condutores','manutencoes','auditoria','abastecimentos','vistorias','melhorias'))
    or (public.f2_perfil() = 'condutor' and colecao in ('chamados','leituras','usos','auditoria','abastecimentos','vistorias'))));

-- Fim. Depois: Authentication → URL Configuration → Site URL = endereço do site no Vercel.
