-- Image de bannière affichée en haut du détail de chaque ligne (URL),
-- facultative.
alter table public.joueur add column banniere_url text;
alter table public.evenement add column banniere_url text;
alter table public.partie add column banniere_url text;
alter table public.jeu add column banniere_url text;
