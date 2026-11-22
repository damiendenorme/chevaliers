-- Lieu où la partie s'est jouée.
alter table public.partie add column lieu text;

-- Parties existantes : un lieu tiré au hasard entre Aumes et Frontignan.
update public.partie
set lieu = case when random() < 0.5 then 'Aumes' else 'Frontignan' end;
