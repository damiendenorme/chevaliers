-- Une partie n'a pas de nom : elle oppose deux joueurs, chacun avec son score.
alter table public.partie drop column nom;

alter table public.partie
  add column joueur1_id bigint not null references public.joueur (id),
  add column joueur2_id bigint not null references public.joueur (id),
  add column score_joueur1 integer not null default 0,
  add column score_joueur2 integer not null default 0;
