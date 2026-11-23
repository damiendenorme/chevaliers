-- Type d'un événement Wargame (facultatif) : élimination, championnat ou
-- ronde suisse. Choisi dans son détail (backoffice).
alter table public.evenement
  add column type text
  check (type in ('elimination', 'championnat', 'suisse'));
