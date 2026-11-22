-- Backoffice : tout utilisateur connecté peut créer, modifier et supprimer
-- dans toutes les tables. L'inscription publique est fermée (config Auth) :
-- les comptes se créent dans le tableau de bord Supabase.
-- La lecture reste publique (politiques existantes).

do $$
declare
  t text;
begin
  foreach t in array array[
    'joueur', 'evenement', 'jeu', 'partie', 'photo',
    'rpg_joueur', 'rpg_evenement', 'rpg_jeu', 'rpg_partie', 'rpg_photo'
  ] loop
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (true)',
      t || ' : ajout par les connectés', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (true) with check (true)',
      t || ' : modification par les connectés', t
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (true)',
      t || ' : suppression par les connectés', t
    );
  end loop;
end
$$;

-- Bucket « photos » : les connectés peuvent y déposer, remplacer et
-- supprimer des fichiers (la lecture est publique, le bucket l'est).
create policy "photos : ajout par les connectés"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'photos');

create policy "photos : modification par les connectés"
  on storage.objects for update to authenticated
  using (bucket_id = 'photos') with check (bucket_id = 'photos');

create policy "photos : suppression par les connectés"
  on storage.objects for delete to authenticated
  using (bucket_id = 'photos');
