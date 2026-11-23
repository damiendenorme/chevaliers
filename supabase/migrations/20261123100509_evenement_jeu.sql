-- Jeu d'un événement Wargame (facultatif) : ses parties se jouent à ce jeu.
alter table public.evenement
  add column jeu_id bigint references public.jeu (id);
