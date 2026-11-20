-- Les bannières sont désormais des assets de l'app
-- (assets/bannieres/<table>/<id>.jpg) : la colonne d'URL ne sert plus.
alter table public.joueur drop column banniere_url;
alter table public.evenement drop column banniere_url;
alter table public.partie drop column banniere_url;
alter table public.jeu drop column banniere_url;
