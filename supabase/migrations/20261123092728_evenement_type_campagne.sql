-- Nouveau type d'événement Wargame : campagne.
alter table public.evenement drop constraint evenement_type_check;
alter table public.evenement
  add constraint evenement_type_check
  check (type in ('elimination', 'championnat', 'suisse', 'campagne'));
