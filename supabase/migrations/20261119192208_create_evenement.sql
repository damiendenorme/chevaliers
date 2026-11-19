create table public.evenement (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

alter table public.evenement enable row level security;

-- Lecture publique (nécessaire pour afficher le nombre d'événements dans
-- l'app). Aucune écriture n'est autorisée via l'API.
create policy "evenement lisible par tous"
  on public.evenement
  for select
  to anon, authenticated
  using (true);
