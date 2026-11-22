-- Parties de JDR : un jeu, un meneur de jeu (MJ), des joueurs invités, un lieu
-- et un événement facultatifs, et une date (jour). Pas de joueur 1/2 ni de
-- score. (Aucune partie JDR n'existait encore.)

alter table public.rpg_partie
  add column mj_id bigint references public.rpg_joueur (id),
  add column evenement_id bigint references public.rpg_evenement (id),
  add column date date not null default current_date;

-- Anciennes colonnes du modèle Wargame : gardées pour l'instant (la version
-- déployée de l'app les lit encore), mais plus obligatoires. À supprimer une
-- fois la nouvelle version déployée.
alter table public.rpg_partie
  alter column joueur1_id drop not null,
  alter column joueur2_id drop not null,
  alter column score_joueur1 drop not null,
  alter column score_joueur2 drop not null;

-- Joueurs invités d'une partie de JDR (plusieurs).
create table public.rpg_partie_joueur (
  partie_id bigint not null references public.rpg_partie (id) on delete cascade,
  joueur_id bigint not null references public.rpg_joueur (id),
  primary key (partie_id, joueur_id)
);

create index rpg_partie_joueur_joueur_id_idx
  on public.rpg_partie_joueur (joueur_id);

-- Lecture publique ; écriture par les connectés (backoffice).
alter table public.rpg_partie_joueur enable row level security;

create policy "rpg_partie_joueur lisible par tous" on public.rpg_partie_joueur
  for select to anon, authenticated using (true);
create policy "rpg_partie_joueur : ajout par les connectés"
  on public.rpg_partie_joueur for insert to authenticated with check (true);
create policy "rpg_partie_joueur : modification par les connectés"
  on public.rpg_partie_joueur for update to authenticated
  using (true) with check (true);
create policy "rpg_partie_joueur : suppression par les connectés"
  on public.rpg_partie_joueur for delete to authenticated using (true);
