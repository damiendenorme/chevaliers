-- Nombre de tours d'un événement Wargame à élimination (facultatif) : son
-- premier tour, des demi-finales aux trente-deuxièmes de finale.
alter table public.evenement
  add column tours text
  check (tours in ('demi', 'quart', 'huitieme', 'seizieme', 'trente_deuxieme'));
