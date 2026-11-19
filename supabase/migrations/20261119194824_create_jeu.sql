create table public.jeu (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

alter table public.jeu enable row level security;

-- Lecture publique, comme les autres tables. Aucune écriture via l'API.
create policy "jeu lisible par tous"
  on public.jeu
  for select
  to anon, authenticated
  using (true);
