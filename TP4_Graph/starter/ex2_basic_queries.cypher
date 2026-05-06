// TP4 - Exercice 2 : Requêtes de Base Neo4j
// Use Case : UniConnect DZ - Réseau Social Universitaire

// ─── 2.1 : Trouver tous les amis d'Ahmed (1 saut) ─────────────────────
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(amis:Etudiant)
RETURN amis.prenom + " " + amis.nom AS nom_complet,
       amis.universite AS universite,
       amis.filiere AS filiere
ORDER BY amis.prenom;

// ─── 2.2 : Trouver les amis d'amis d'Ahmed qui ne sont pas déjà ses amis ─────
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT*1..2]-(potentiels:Etudiant)
WHERE NOT (ahmed)-[:CONNAIT]-(potentiels)
RETURN DISTINCT potentiels.prenom + " " + potentiels.nom AS suggestion,
       potentiels.universite AS universite,
       potentiels.filiere AS filiere,
       // Calculer la distance sociale
       length shortestPath((ahmed)-[:CONNAIT*]-(potentiels)) AS distance
ORDER BY distance
LIMIT 10;

// ─── 2.3 : Étudiants qui suivent le même cours que Fatima mais ne la connaissent pas ─────
MATCH (fatima:Etudiant {prenom: "Fatima"})-[:SUIT]-(cours:Cours)
MATCH (etudiants:Etudiant)-[:SUIT]-(cours)
WHERE etudiants <> fatima
  AND NOT (fatima)-[:CONNAIT]-(etudiants)
RETURN DISTINCT etudiants.prenom + " " + etudiants.nom AS nom_complet,
       etudiants.universite AS universite,
       etudiants.filiere AS filiere,
       collect(cours.intitule) AS cours_communs
ORDER BY etudiants.prenom
LIMIT 15;

// ─── 2.4 : Clubs les plus populaires (par nombre de membres) ───────────────
MATCH (club:Club)<-[:MEMBRE_DE]-(etudiants:Etudiant)
RETURN club.nom AS club_nom,
       club.universite AS universite,
       club.domaine AS domaine,
       count(etudiants) AS nb_membres,
       collect(etudiants.universite)[0..3] AS universites_representees
ORDER BY nb_membres DESC
LIMIT 10;

// ─── 2.5 : Profil complet d'un étudiant : amis, cours, compétences, clubs ─────
MATCH (etudiant:Etudiant {prenom: "Ahmed"})
OPTIONAL MATCH (etudiant)-[:CONNAIT]-(amis:Etudiant)
OPTIONAL MATCH (etudiant)-[:SUIT]-(cours:Cours)
OPTIONAL MATCH (etudiant)-[:MAITRISE]-(competence:Competence)
OPTIONAL MATCH (etudiant)-[:MEMBRE_DE]-(club:Club)
RETURN etudiant.prenom + " " + etudiant.nom AS nom_complet,
       etudiant.universite AS universite,
       etudiant.filiere AS filiere,
       etudiant.annee AS annee,
       {
         amis: [a.prenom + " " + a.nom IN amis.prenom + " " + amis.nom | a.prenom + " " + a.nom],
         nb_amis: count(amis)
       } AS reseau_social,
       {
         cours: [c.code + " - " + c.intitule IN cours.code | c.code + " - " + c.intitule],
         nb_cours: count(cours)
       } AS parcours_academique,
       {
         competences: [comp.nom + " (" + comp.niveau + ")" IN competence.nom | comp.nom + " (" + comp.niveau + ")"],
         nb_competences: count(competence)
       } AS profil_technique,
       {
         clubs: [cl.nom IN club.nom | cl.nom],
         nb_clubs: count(club)
       } AS vie_etudiante;

// ─── Requêtes additionnelles pour démonstration ─────────────────────────────

// Étudiants par université
MATCH (e:Etudiant)
RETURN e.universite AS universite,
       count(e) AS nb_etudiants,
       collect(DISTINCT e.filiere) AS filieres_representees
ORDER BY nb_etudiants DESC;

// Distribution des compétences par catégorie
MATCH (e:Etudiant)-[:MAITRISE]-(c:Competence)
RETURN c.categorie AS categorie,
       collect(DISTINCT c.nom) AS competences,
       count(c) AS nb_etudiants,
       avg(size((e)-[:MAITRISE]-())) AS avg_competences_par_etudiant
ORDER BY nb_etudiants DESC;

// Relations inter-universités
MATCH (e1:Etudiant)-[:CONNAIT]-(e2:Etudiant)
WHERE e1.universite <> e2.universite
RETURN e1.universite + " → " + e2.universite AS connexion_inter_universites,
       count(*) AS nb_connexions
ORDER BY nb_connexions DESC
LIMIT 10;

// Étudiants avec le plus de compétences
MATCH (e:Etudiant)-[:MAITRISE]-(c:Competence)
WITH e, count(c) AS nb_competences
RETURN e.prenom + " " + e.nom AS nom_complet,
       e.universite AS universite,
       e.filiere AS filiere,
       nb_competences
ORDER BY nb_competences DESC
LIMIT 10;

// Cours les plus suivis
MATCH (c:Cours)<-[:SUIT]-(e:Etudiant)
RETURN c.intitule AS cours_intitule,
       c.code AS code,
       count(e) AS nb_etudiants,
       avg(e.note) AS note_moyenne
ORDER BY nb_etudiants DESC
LIMIT 10;
