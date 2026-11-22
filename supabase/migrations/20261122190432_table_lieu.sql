-- Lieux possibles des parties : Aumes et Frontignan, dans une table. Les
-- parties y font référence au lieu de stocker un texte libre.
-- Wargame : lieu ; RPG : rpg_lieu (données séparées, mêmes lieux).

create table public.lieu (
  id bigint generated always as identity primary key,
  nom text not null unique,
  created_at timestamptz not null default now()
);

create table public.rpg_lieu (
  id bigint generated always as identity primary key,
  nom text not null unique,
  created_at timestamptz not null default now()
);

insert into public.lieu (nom) values ('Aumes'), ('Frontignan');
insert into public.rpg_lieu (nom) values ('Aumes'), ('Frontignan');

-- Les parties pointent vers leur lieu (facultatif).
alter table public.partie
  add column lieu_id bigint references public.lieu (id);
alter table public.rpg_partie
  add column lieu_id bigint references public.rpg_lieu (id);

-- Reprise des lieux déjà saisis, sans tenir compte de la casse (« AUMES »).
update public.partie p
set lieu_id = l.id
from public.lieu l
where lower(trim(p.lieu)) = lower(l.nom);

update public.rpg_partie p
set lieu_id = l.id
from public.rpg_lieu l
where lower(trim(p.lieu)) = lower(l.nom);

-- L'ancienne colonne texte « lieu » est gardée pour l'instant : la version
-- déployée de l'app la lit encore. À supprimer une fois la nouvelle version
-- déployée.

-- Lecture publique ; écriture par les connectés (backoffice).
alter table public.lieu enable row level security;
alter table public.rpg_lieu enable row level security;

create policy "lieu lisible par tous" on public.lieu
  for select to anon, authenticated using (true);
create policy "rpg_lieu lisible par tous" on public.rpg_lieu
  for select to anon, authenticated using (true);

create policy "lieu : ajout par les connectés" on public.lieu
  for insert to authenticated with check (true);
create policy "lieu : modification par les connectés" on public.lieu
  for update to authenticated using (true) with check (true);
create policy "lieu : suppression par les connectés" on public.lieu
  for delete to authenticated using (true);

create policy "rpg_lieu : ajout par les connectés" on public.rpg_lieu
  for insert to authenticated with check (true);
create policy "rpg_lieu : modification par les connectés" on public.rpg_lieu
  for update to authenticated using (true) with check (true);
create policy "rpg_lieu : suppression par les connectés" on public.rpg_lieu
  for delete to authenticated using (true);
