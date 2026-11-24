-- Suisse Wargame : son nombre de tours (chaque tour est un championnat par
-- groupes) et le nombre de joueurs par groupe (null : pas encore choisi).
-- Ses playoffs utilisent la colonne playoffs, comme le championnat.
alter table public.evenement
  add column suisse_tours smallint check (suisse_tours >= 1),
  add column suisse_groupe smallint check (suisse_groupe >= 2);

-- Tour du suisse auquel une partie a été jouée (0 : le premier ; null :
-- hors tour).
alter table public.partie
  add column evenement_tour smallint check (evenement_tour >= 0);
