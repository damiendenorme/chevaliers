create table public.joueur (
  id bigint generated always as identity primary key,
  nom text not null,
  created_at timestamptz not null default now()
);

-- RLS activée sans politique : la table n'est pas accessible via l'API publique
-- tant qu'aucune règle d'accès n'est ajoutée.
alter table public.joueur enable row level security;
