create table public.partie (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

alter table public.partie enable row level security;

-- Lecture publique (nécessaire pour afficher le nombre de parties dans l'app).
-- Aucune écriture n'est autorisée via l'API.
create policy "partie lisible par tous"
  on public.partie
  for select
  to anon, authenticated
  using (true);
