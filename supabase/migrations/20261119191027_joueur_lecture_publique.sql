-- Lecture publique de la table joueur (nécessaire pour afficher le nombre de
-- joueurs dans l'app). Aucune écriture n'est autorisée via l'API.
create policy "joueur lisible par tous"
  on public.joueur
  for select
  to anon, authenticated
  using (true);
