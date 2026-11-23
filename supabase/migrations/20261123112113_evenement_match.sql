-- Tableau d'un événement Wargame à élimination : un match par tour
-- (0 : premier tour) et par position dans le tour (0 : en haut).
-- Les joueurs ne sont enregistrés qu'au premier tour : ensuite, ce sont les
-- vainqueurs des deux matchs précédents. Une fois joué, le match renvoie à
-- sa partie (scores, vainqueur).
create table public.evenement_match (
  evenement_id bigint not null references public.evenement (id) on delete cascade,
  tour smallint not null check (tour >= 0),
  position smallint not null check (position >= 0),
  joueur1_id bigint references public.joueur (id),
  joueur2_id bigint references public.joueur (id),
  partie_id bigint references public.partie (id) on delete set null,
  primary key (evenement_id, tour, position)
);

-- Lecture publique ; écriture par les connectés (backoffice).
alter table public.evenement_match enable row level security;

create policy "evenement_match lisible par tous" on public.evenement_match
  for select to anon, authenticated using (true);
create policy "evenement_match : ajout par les connectés"
  on public.evenement_match for insert to authenticated with check (true);
create policy "evenement_match : modification par les connectés"
  on public.evenement_match for update to authenticated
  using (true) with check (true);
create policy "evenement_match : suppression par les connectés"
  on public.evenement_match for delete to authenticated using (true);
