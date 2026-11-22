-- Photos d'une partie : 0 à plusieurs par partie. L'image est dans le bucket
-- Storage « photos » ; chemin = chemin du fichier dans ce bucket.
create table public.photo (
  id bigint generated always as identity primary key,
  partie_id bigint not null references public.partie (id) on delete cascade,
  chemin text not null,
  created_at timestamptz not null default now()
);

create index photo_partie_id_idx on public.photo (partie_id);

alter table public.photo enable row level security;

-- Lecture publique, comme les autres tables. Aucune écriture via l'API.
create policy "photo lisible par tous"
  on public.photo
  for select
  to anon, authenticated
  using (true);

-- Bucket public : les images se lisent par leur URL publique. Les fichiers
-- se déposent depuis le tableau de bord Supabase.
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;
