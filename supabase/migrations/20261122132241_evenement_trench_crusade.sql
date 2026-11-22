-- « Trench Crusade 2027 » devient « Trench Crusade », en décembre 2027 (jour
-- inconnu : le 1er, qui n'est pas affiché).
update public.evenement
set nom = 'Trench Crusade', date = '2027-12-01'
where nom = 'Trench Crusade 2027';
