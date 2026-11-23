-- Parties Wargame : un événement facultatif, comme au RPG.
alter table public.partie
  add column evenement_id bigint references public.evenement (id);

create index partie_evenement_id_idx on public.partie (evenement_id);
