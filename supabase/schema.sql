-- Base publique de Zando Prix. À coller une seule fois dans Supabase > SQL Editor > Run.
-- Tout le monde peut lire et ajouter un relevé, sans compte.
-- Personne ne peut modifier ou supprimer un relevé d'autrui depuis le site.

create table public.releves (
  id uuid primary key,
  jeton uuid not null,
  produit text not null check (produit ~ '^[a-z-]{2,30}$'),
  departement text not null check (departement in (
    'Bouenza', 'Brazzaville', 'Congo-Oubangui', 'Cuvette', 'Cuvette-Ouest',
    'Djoué-Léfini', 'Kouilou', 'Lékoumou', 'Likouala', 'Niari',
    'Nkéni-Alima', 'Plateaux', 'Pointe-Noire', 'Pool', 'Sangha')),
  ville text not null check (char_length(btrim(ville)) between 1 and 40),
  marche text not null check (char_length(btrim(marche)) between 1 and 60),
  prix integer not null check (prix between 1 and 10000000),
  date_releve date not null,
  cree_le timestamptz not null default now()
);
create index releves_recents on public.releves (date_releve desc, cree_le desc);

alter table public.releves enable row level security;
revoke all on public.releves from anon, authenticated;

-- Le jeton n'est jamais lisible : il prouve seulement qui a créé le relevé.
grant select (id, produit, departement, ville, marche, prix, date_releve, cree_le)
  on public.releves to anon, authenticated;
grant insert (id, jeton, produit, departement, ville, marche, prix, date_releve)
  on public.releves to anon, authenticated;

create policy "lecture publique" on public.releves
  for select to anon, authenticated using (true);
create policy "ajout public" on public.releves
  for insert to anon, authenticated
  with check (date_releve between current_date - 90 and current_date + 1);

-- Limite anti-abus : 40 relevés par heure et par connexion.
-- L'adresse IP n'est conservée que sous forme d'empreinte, effacée après deux heures.
create table public.limites_envoi (
  empreinte text not null,
  heure timestamptz not null,
  nb integer not null,
  primary key (empreinte, heure)
);
alter table public.limites_envoi enable row level security;
revoke all on public.limites_envoi from anon, authenticated;

create function public.controler_envoi() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  en_tetes text := nullif(current_setting('request.headers', true), '');
  adresse text := 'inconnue';
  h timestamptz := date_trunc('hour', now());
  cle text;
  total integer;
begin
  if en_tetes is not null then
    adresse := coalesce(split_part(en_tetes::json ->> 'x-forwarded-for', ',', 1), 'inconnue');
  end if;
  cle := encode(pg_catalog.sha256(convert_to(adresse || to_char(h, 'YYYYMMDDHH24'), 'UTF8')), 'hex');
  delete from public.limites_envoi where heure < h - interval '2 hours';
  insert into public.limites_envoi (empreinte, heure, nb) values (cle, h, 1)
    on conflict (empreinte, heure) do update set nb = public.limites_envoi.nb + 1
    returning nb into total;
  if total > 40 then
    raise exception 'trop_envois' using errcode = 'P0001';
  end if;
  new.ville := btrim(new.ville);
  new.marche := btrim(new.marche);
  return new;
end;
$$;
revoke all on function public.controler_envoi() from public, anon, authenticated;

create trigger controle_avant_ajout before insert on public.releves
  for each row execute function public.controler_envoi();

-- Permet d'annuler sa propre saisie pendant 24 heures, grâce au jeton gardé sur le téléphone.
create function public.supprimer_releve(p_id uuid, p_jeton uuid) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  n integer;
begin
  delete from public.releves
    where id = p_id and jeton = p_jeton and cree_le > now() - interval '24 hours';
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke all on function public.supprimer_releve(uuid, uuid) from public;
grant execute on function public.supprimer_releve(uuid, uuid) to anon, authenticated;
