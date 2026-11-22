-- Parties de JDR : de 0 à plusieurs MJ. Le rôle passe dans la liste des
-- joueurs de la partie : mj = vrai pour un meneur.
alter table public.rpg_partie_joueur
  add column mj boolean not null default false;

-- Reprise du MJ unique de chaque partie.
insert into public.rpg_partie_joueur (partie_id, joueur_id, mj)
select id, mj_id, true
from public.rpg_partie
where mj_id is not null
on conflict (partie_id, joueur_id) do update set mj = true;

-- rpg_partie.mj_id n'est plus utilisée : à supprimer une fois la nouvelle
-- version de l'app déployée (avec les autres anciennes colonnes).
