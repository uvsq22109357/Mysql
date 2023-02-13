-----1.Etude globale------
--a--Répartition Adhérent/VIP...
ALTER TABLE client ADD type_client varchar(10);
UPDATE client set type_client = (case 
					when vip = 1 then 'VIP'
					else 
								 case
							
					when DATE_PART('year', datedebutadhesion) = 2016 then 'NEW_N2'
					when DATE_PART('year', datedebutadhesion) = 2017 then 'NEW_N1'
					else 
								 case
					when datefinadhesion>'2018-01-01' then 'ADHERENT'
					else 'CHURNER'
					end
					end
end);

select type_client, count(distinct idclient) as nb_clients from client
group by type_client;

--Création d’un subset avec moins de lignes :
drop table IF EXISTS lignes_ticket_subset;
drop table IF EXISTS entete_ticket_subset;
create table lignes_ticket_subset as select * from lignes_ticket limit 10000; 
create table entete_ticket_subset as select * from entete_ticket limit 10000;

--b--CA GLOBAL par client N-2 vs N-1
select DATE_PART('year', tic_date) as Année, idclient, sum(tic_totalttc) as CA from entete_ticket_subset	
where DATE_PART('year', tic_date) in (2016,2017)
group by Année, idclient;
--Application sur la table originale
select DATE_PART('year', tic_date) as Année, idclient, sum(tic_totalttc) as CA from entete_ticket
where DATE_PART('year', tic_date) in (2016,2017)
group by Année, idclient;

--c--Répartition par âge x sexe
-- Vous remarquez que plusieurs label designe la meme civilite, créez une nouvelle variable correctement codée (un label = une civilité unique)
ALTER TABLE client ADD civilite_new varchar(10);
UPDATE client set civilite_new = (case 
					when civilite in ('Mr','monsieur','MONSIEUR') then 'Monsieur'
					when civilite in ('Mme','madame','MADAME') then 'Madame'
					else null
end);
select distinct(civilite_new) from client;
alter table client drop column civilite;
alter table client RENAME COLUMN civilite_new TO civilite;
select * from client;

-- Créez une nouvelle colonne qui définit l'age du client
ALTER TABLE client ADD AGE integer;
update client set age = 2018 - DATE_PART('year', datenaissance);

---Pour cette partie, on s'intérésse à traiter la colonne âge (il y a plus que 300k clients sans âge qu'on peut pas les ignorer)
---Alors, on a décidé de remplacer les ages manquants par la moyenne des âges (50ans)
---Finalement, on a choisi de faire l'analyse sur les clients âgés de 18 jusqu'à 100 ans!
select avg(age) from client
--création d'une copie de la table client (on procéde avec la table client_test)	
drop table IF EXISTS client_test;
create table client_test as select * from client;
--Remplacement des âges manquants par 50 ans
UPDATE client_test set age = (case 
					when age isnull then 50
				 	else age
end);
select * from client_test
--Elimination des clients avec âge<18 et âge>100 (0,13% de la table)
select count(idclient) from client_test
select count(idclient) from client_test
where age<18 or age >100
delete from client_test where age<18 or age >100
--Ajout d'une colonne qui nous donne les tranches d'âges vu que c'est pas évident de représenter 83 lignes d'âge ainsi 
-- que le sexe dans un seul graphique
alter table client_test drop column tranche_age;
ALTER TABLE client_test ADD tranche_age varchar(20);
UPDATE client_test set tranche_age = (case 
					when age <= 20 then 'Inf ou égal à 20 ans'
					when age>20 and age<=30 then '21 à 30 ans' 
					when age>30 and age<=40 then '31 à 40 ans' 
					when age>40 and age<=50 then '41 à 50 ans' 
					when age>50 and age<=60 then '51 à 60 ans' 
					when age>60 and age<=70 then '61 à 70 ans' 
					when age>70 and age<=80 then '71 à 80 ans' 
					when age>80 and age<=90 then '81 à 90 ans' 	
					when age>90 and age<=100 then '91 à 100 ans' 

end);
select * from client_test
select idclient, civilite,age, tranche_age from client_test
order by age;

----Etude par magasin----
--a--Résultat par magasin

--Ajout des colonnes pour les clients actifs sur 2016 et 2017
alter table client_test drop column actif2016

alter table client_test add actif2016 float(1);
UPDATE client_test set actif2016 = (case 
					when DATE_PART('year',datedebutadhesion)<=2016 and DATE_PART('year',datefinadhesion) >=2016 then 1
				 	else 0
end);
alter table client_test drop column actif2017
alter table client_test add actif2017 float(1);
UPDATE client_test set actif2017 = (case 
					when DATE_PART('year',datedebutadhesion)<=2017 and DATE_PART('year',datefinadhesion) >=2017 then 1
				 	else 0
end);
--Clients, clients actifs sur 2016 et 2017 et évolution des clients de 2016 à 2017 par magasin
select magasin, count(idclient), sum(actif2016) as sum2016, sum(actif2017) as sum2017,(sum(actif2017)-sum(actif2016))/ sum(actif2016) as évolution_clients from client_test
group by magasin
--Total_TTC 2016
select mag_code, sum(tic_totalttc) from entete_ticket
where DATE_PART('year',tic_date) = 2016
group by mag_code
--Total_TTC 2017
select mag_code, sum(tic_totalttc) from entete_ticket
where DATE_PART('year',tic_date) = 2017
group by mag_code

--b--Distance Client/magasin
select codeinsee,count(idclient) from client_test
group by codeinsee
select * from ref_magasin
select * from client_test


---Importation de la table Data_gps-----
----------------------------------------
drop table IF EXISTS data_gps;
create table data_gps 
(
	Code_INSEE varchar(15) primary key,
	Commune varchar(50),
	Latitude varchar(50),
	Longitude varchar(50)
);
COPY data_gps FROM 'C:\Users\Public\Projet\Data_Transverse\data_gps.CSV' CSV HEADER delimiter ';' null '';

---TRANSFORMATION latitude
ALTER TABLE data_gps ADD lat float;
UPDATE data_gps SET lat =  CAST(REPLACE(latitude , ',', '.') AS float);
ALTER TABLE data_gps DROP latitude;
---TRANSFORMATION longitude
ALTER TABLE data_gps ADD long float;
UPDATE data_gps SET long =  CAST(REPLACE(longitude , ',', '.') AS float);
ALTER TABLE data_gps DROP longitude;

SELECT * from data_gps;

--Construction des colonnes latitude et longitude pour chaque client et chaque magasin

--Correction manuelle de qlqs valeurs pour la colonne 'ville ' dans la table ref_magasin pour que ce soit adéquate avec les communes
--de notre base GPS
UPDATE ref_magasin set ville = (case 
					when ville = 'GILLY SUR ISERE' then 'GILLY-SUR-ISERE'
					when ville = 'LES MILLES' then 'ALLAS-LES-MINES' 
					when ville = 'ST GENIS POUILLY' then 'SAINT-GENIS-POUILLY' 
					when ville = 'LABEGE CEDEX' then 'LABEGE' 
					when ville = 'VARENNES VAUZELLES' then 'VARENNES-VAUZELLES' 
					when ville = 'SAINTE MAXIME' then 'SAINTE-MAXIME' 
					when ville = 'SARGE LES LE MANS' then 'SARGE-LES-LE-MANS' 
					when ville = 'ST JULIEN EN GENEVOIS CEDEX' then 'SAINT-JULIEN-EN-GENEVOIS' 	
					when ville = 'VIVIER AU COURT' then 'VIVIER-AU-COURT' 
					when ville = 'NEVERS CEDEX' then 'NEVERS'
					when ville = 'CAGNES SUR MER' then 'CAGNES-SUR-MER'
					when ville = 'RUEIL MALMAISON' then 'RUEIL-MALMAISON'
					else ville
end);
						
--latitude magasin
alter table ref_magasin drop column lat_mag;
ALTER TABLE ref_magasin ADD lat_mag float;

UPDATE ref_magasin 
SET lat_mag = tab.lat 
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.commune = ref_magasin.ville;

--Longitude magasin
alter table ref_magasin drop column long_mag;
ALTER TABLE ref_magasin ADD long_mag float;

UPDATE ref_magasin 
SET long_mag = tab.long
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.commune = ref_magasin.ville;

--Latitude client
alter table client_test drop column lat_client;
ALTER TABLE client_test ADD lat_client float;

UPDATE client_test 
SET lat_client = tab.lat
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.code_insee = client_test.codeinsee;

--Longitude client
alter table client_test drop column long_client;
ALTER TABLE client_test ADD long_client float;

UPDATE client_test 
SET long_client = tab.long
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.code_insee = client_test.codeinsee;

--NB : On a 121518 lignes sans coordonnées gps parce que leur code insee soit il n'existe pas soit il est mal saisi (14,38% de notre base)
--27360 clients n'ont pas un code insee (3,23% de la base clients) qu'on va les éliminer de l'étude distance client/magasin
select * from client_test
where codeinsee isnull;

--94158 clients ont un code insee non valide (11,15% de la base) qu'on va essayer de les corriger 
select * from client_test
where codeinsee is not null and lat_client isnull;

--Notre premier réflexe était la suppression de '0' qui se trouve au début de plusieurs valeurs de codeinsee (87309 cas)
select * from client_test
where codeinsee like '0%'

UPDATE client_test set codeinsee = (case 
					when codeinsee like '0%' then ltrim(codeinsee,'0')
					else codeinsee
end);

--Réapplication du remplissage latitude et longitude
UPDATE client_test 
SET lat_client = tab.lat
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.code_insee = client_test.codeinsee;

UPDATE client_test 
SET long_client = tab.long
FROM (SELECT * FROM data_gps) AS tab
WHERE tab.code_insee = client_test.codeinsee;
--Il nous reste que 35108  des clients avec des code insee invalides ou manquants (4,15% de la base) qu'on a décidé de les éliminer de l'étude
select count(*) from client_test
where lat_client isnull;

--On va procéder avec la table 'client_test1' qui contient que des clients avec des coordonnées gps valides (809609 clients)
drop table IF EXISTS client_test1;
create table client_test1 as select * from client_test;

delete from client_test1
where lat_client isnull;

select * from client_test1;

--Importation des coordonnées des magasins pour chaque client
--Latitde magasin
alter table client_test1 drop column lat_mag;
ALTER TABLE client_test1 ADD lat_mag float;

UPDATE client_test1 
SET lat_mag = tab.lat_mag
FROM (SELECT * FROM ref_magasin) AS tab
WHERE tab.codesociete = client_test1.magasin;

--Longitude magasin
alter table client_test1 drop column long_mag;
ALTER TABLE client_test1 ADD long_mag float;

UPDATE client_test1 
SET long_mag = tab.long_mag
FROM (SELECT * FROM ref_magasin) AS tab
WHERE tab.codesociete = client_test1.magasin;

select * from client_test1;

--Création de la colonne distance qui prend en entrée 4 variables (lat_client, long_client, lat_mag et long_mag) et nous retourne 
--comme résultat la distance en Km
alter table client_test1 drop column Distance;
ALTER TABLE client_test1 ADD Distance numeric;

--Il faut changer le type pour les colonnes latitude et longitude en numeric pour que la fonction distance puisse être exécutée!!
alter table client_test1 ALTER lat_client type numeric;
alter table client_test1 ALTER long_client type numeric;
alter table client_test1 ALTER lat_mag type numeric;
alter table client_test1 ALTER long_mag type numeric;

Update client_test1
set distance = ACOS(SIN(RADIANS(lat_client))*SIN(RADIANS(lat_mag))+COS(RADIANS(lat_client))*COS(RADIANS(lat_mag))*COS(RADIANS(long_client-long_mag)))*6371;
--Checking!
select max(distance), avg(distance),min(distance),count(distance) from client_test1;

--Construction d'une colonne intervalle_distance
alter table client_test1 drop column intervalle_distance;
ALTER TABLE client_test1 ADD intervalle_distance varchar(20);
UPDATE client_test1 set intervalle_distance = (case 
					when distance >= 0 and distance < 5 then '0 à 5 km' 
					when distance >= 5 and distance < 10 then '5 à 10 km'
					when distance >= 10 and distance < 20 then '10 à 20 km' 
					when distance >= 20 and distance < 50 then '20 à 50 km' 
					else 'Plus de 50 km'

end);

select intervalle_distance, count(idclient) from client_test1
group by intervalle_distance
order by intervalle_distance;

----Etude par Univers----
--a--Etude par univers
--Attention! cette requête prend du temps!
--On va pivoter la table génerée % à la colonne 'Année' sur notre outil de Data viz, on construit aussi la colonne évolution, 
--ça nous fera gagner du temps.
select DATE_PART('year', tic_date) as Année, codeunivers as univers, sum(tic_totalttc) as CA from entete_ticket
inner join lignes_ticket on entete_ticket.idticket = lignes_ticket.idticket
inner join ref_article on ref_article.codearticle = lignes_ticket.idarticle
where DATE_PART('year', tic_date) in (2016,2017)
group by Année, univers;

--b--Top par Univers
select * from ref_article;

--On construit tout d'abord la table de toutes les familles par univers avec leurs chiffres d'affaires
--ça nous rend une table de 25 lignes contenant toutes les 25 familles possibles et leurs CA listées par univers 
create table famille_univers as (select  codeunivers as univers, codefamille as famille, sum(tic_totalttc) as CA from entete_ticket
inner join lignes_ticket on entete_ticket.idticket = lignes_ticket.idticket
inner join ref_article on ref_article.codearticle = lignes_ticket.idarticle
where DATE_PART('year', tic_date) in (2016,2017)
group by univers, famille);

select * from famille_univers;

--On s'intéresse maintenant à sélectionner les top 5 familles par univers!
select table1.* from famille_univers as table1
inner join
(select univers, max(ca) as max_ca
from famille_univers
group by univers) as table2
on table1.univers = table2.univers and table1.ca = table2.max_ca
where table1.univers <> 'COUPON';
-------------------------------------------------------------!!THE END!!---------------------------------------------------------------