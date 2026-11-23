-- Championnat Wargame : ses rencontres (aller simple ou aller-retour ; null :
-- pas encore choisi), ses playoffs (premier tour, ou « aucun » ; null : pas
-- encore choisi) et son barème : points à la victoire, au nul, à la
-- défaite, ou bien la Gloire gagnée (gains de ELO) en guise de points.
alter table public.evenement
  add column aller_retour boolean,
  add column playoffs text
    check (playoffs in ('aucun', 'demi', 'quart', 'huitieme', 'seizieme', 'trente_deuxieme')),
  add column points_victoire smallint not null default 3,
  add column points_nul smallint not null default 1,
  add column points_defaite smallint not null default 0,
  add column points_gloire boolean not null default false;
