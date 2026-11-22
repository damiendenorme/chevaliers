-- Résumé textuel d'une partie (facultatif), affiché dans son détail.
alter table public.partie add column resume text;
alter table public.rpg_partie add column resume text;
