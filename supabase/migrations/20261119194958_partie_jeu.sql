-- Chaque partie se joue à un jeu.
alter table public.partie
  add column jeu_id bigint not null references public.jeu (id);
