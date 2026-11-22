-- Données de la page RPG : mêmes entités que le Wargame, entièrement
-- séparées (aucune donnée partagée), préfixées par rpg_.

create table public.rpg_joueur (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

create table public.rpg_evenement (
  id bigint generated always as identity primary key,
  nom text not null,
  -- Jour de l'événement, facultatif.
  date date,
  created_at timestamptz not null default now()
);

create table public.rpg_jeu (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

create table public.rpg_partie (
  id bigint generated always as identity primary key,
  joueur1_id bigint not null references public.rpg_joueur (id),
  joueur2_id bigint not null references public.rpg_joueur (id),
  score_joueur1 integer not null default 0,
  score_joueur2 integer not null default 0,
  jeu_id bigint not null references public.rpg_jeu (id),
  lieu text,
  created_at timestamptz not null default now()
);

-- Photos d'une partie RPG : 0 à plusieurs, dans le bucket « photos ».
create table public.rpg_photo (
  id bigint generated always as identity primary key,
  partie_id bigint not null references public.rpg_partie (id) on delete cascade,
  chemin text not null,
  created_at timestamptz not null default now()
);

create index rpg_photo_partie_id_idx on public.rpg_photo (partie_id);

-- Lecture publique, comme les autres tables. Aucune écriture via l'API.
alter table public.rpg_joueur enable row level security;
alter table public.rpg_evenement enable row level security;
alter table public.rpg_jeu enable row level security;
alter table public.rpg_partie enable row level security;
alter table public.rpg_photo enable row level security;

create policy "rpg_joueur lisible par tous" on public.rpg_joueur
  for select to anon, authenticated using (true);
create policy "rpg_evenement lisible par tous" on public.rpg_evenement
  for select to anon, authenticated using (true);
create policy "rpg_jeu lisible par tous" on public.rpg_jeu
  for select to anon, authenticated using (true);
create policy "rpg_partie lisible par tous" on public.rpg_partie
  for select to anon, authenticated using (true);
create policy "rpg_photo lisible par tous" on public.rpg_photo
  for select to anon, authenticated using (true);
