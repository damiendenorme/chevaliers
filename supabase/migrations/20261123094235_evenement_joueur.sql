-- Joueurs inscrits à un événement Wargame : on les ajoute à l'événement,
-- puis on crée ses parties entre eux.
create table public.evenement_joueur (
  evenement_id bigint not null references public.evenement (id) on delete cascade,
  joueur_id bigint not null references public.joueur (id),
  primary key (evenement_id, joueur_id)
);

create index evenement_joueur_joueur_id_idx
  on public.evenement_joueur (joueur_id);

-- Reprise : ceux qui ont déjà joué à une partie de l'événement.
insert into public.evenement_joueur (evenement_id, joueur_id)
select evenement_id, joueur1_id from public.partie where evenement_id is not null
union
select evenement_id, joueur2_id from public.partie where evenement_id is not null
on conflict do nothing;

-- Lecture publique ; écriture par les connectés (backoffice).
alter table public.evenement_joueur enable row level security;

create policy "evenement_joueur lisible par tous" on public.evenement_joueur
  for select to anon, authenticated using (true);
create policy "evenement_joueur : ajout par les connectés"
  on public.evenement_joueur for insert to authenticated with check (true);
create policy "evenement_joueur : modification par les connectés"
  on public.evenement_joueur for update to authenticated
  using (true) with check (true);
create policy "evenement_joueur : suppression par les connectés"
  on public.evenement_joueur for delete to authenticated using (true);
