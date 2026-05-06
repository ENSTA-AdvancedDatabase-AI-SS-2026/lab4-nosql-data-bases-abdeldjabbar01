// TP4 - Exercice 4 : Requêtes Avancées Neo4j
// Use Case : UniConnect DZ - Analyse Réseau Social Complexe

// ─── 4.1 : Trouver un tuteur ─────────────────────────────────────────────
// "Étudiant en Master qui maîtrise Python et a eu >14/20 en BDD"
MATCH (tuteur:Etudiant)-[:SUIT]-(cours:Cours {code: "INFO401"})
WHERE tuteur.annee >= 4  // Master = années 4-5
  AND (tuteur)-[:MAITRISE]-(python:Competence {nom: "Python"})
  AND (tuteur)-[:SUIT]-(cours)-[r:SUIT {note > 14}]
RETURN tuteur.prenom + " " + tuteur.nom AS tuteur,
       tuteur.universite AS universite,
       tuteur.annee AS annee,
       r.note AS note_en_bdd,
       // Vérifier les compétences avancées
       [(tuteur)-[:MAITRISE]-(c:Competence {niveau: "Avancé"}) | c.nom] AS competences_avancees
ORDER BY r.note DESC
LIMIT 5;

// ─── 4.2 : Réseau alumni dans une entreprise ───────────────────────────────
// "Qui de mon réseau (jusqu'à 3 sauts) travaille chez Sonatrach ?"
MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH path = (moi)-[:CONNAIT*1..3]-(alumni:Etudiant)
WHERE (alumni)-[:A_STAGE_CHEZ]-(entreprise:Entreprise {nom: "Sonatrach"})
RETURN DISTINCT alumni.prenom + " " + alumni.nom AS nom_alumni,
       alumni.universite AS universite,
       alumni.filiere AS filiere,
       length(path) AS distance_sociale,
       // Détails du stage
       [(alumni)-[r:A_STAGE_CHEZ]->(entreprise) | 
        "Stage " + toString(r.annee) + " (" + toString(r.duree_mois) + " mois)"] AS details_stage
ORDER BY distance_sociale, alumni.annee DESC;

// Alternative : Recherche dans toutes les entreprises pétrolières algériennes
MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH path = (moi)-[:CONNAIT*1..3]-(alumni:Etudiant)
WHERE (alumni)-[:A_STAGE_CHEZ]-(entreprise:Entreprise)
  AND entreprise.nom IN ["Sonatrach", "Naftal", "Sonelgaz", "Engie", "Eni"]
RETURN DISTINCT 
  entreprise.nom AS entreprise,
  collect(DISTINCT alumni.prenom + " " + alumni.nom) AS alumni_trouves,
  count(DISTINCT alumni) AS nb_alumni,
  min(length(path)) AS distance_minimale
ORDER BY nb_alumni DESC;

// ─── 4.3 : Détection de ponts ───────────────────────────────────────────────
// Quels étudiants connectent des communautés isolées ?
// Utiliser l'algorithme de betweenness centrality

// Créer la projection pour l'analyse
CALL gds.graph.project(
  'reseau_social_etendu',
  'Etudiant',
  'CONNAIT'
);

// Calculer la betweenness centrality pour détecter les ponts
CALL gds.betweenness.stream('reseau_social_etendu')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).prenom + " " + gds.util.asNode(nodeId).nom AS pont_potentiel,
       gds.util.asNode(nodeId).universite AS universite,
       score AS betweenness_score,
       // Compter les connexions inter-universités (indicateur de pont)
       size([(gds.util.asNode(nodeId))-[:CONNAIT]-(autre)-[:CONNAIT]-(troisieme) 
             WHERE gds.util.asNode(nodeId).universite <> autre.universite 
               AND autre.universite <> troisieme.universite]) AS connexions_inter_universites
ORDER BY betweenness_score DESC
LIMIT 10;

// Alternative : Détection manuelle des ponts
MATCH (pont:Etudiant)-[:CONNAIT]-(groupe1:Etudiant)
WHERE NOT (pont)-[:CONNAIT]-(groupe1)
  AND NOT (groupe1)-[:CONNAIT*2]-(pont)
WITH pont, groupe1, 
     count(DISTINCT (pont)-[:CONNAIT]-()) AS nb_reseaux_pont
WHERE nb_reseaux_pont > 2  // Connecte au moins 3 réseaux différents
RETURN pont.prenom + " " + pont.nom AS pont_structurel,
       pont.universite AS universite,
       nb_reseaux_pont,
       // Exemples de groupes connectés
       [(pont)-[:CONNAIT]-(e)-[:CONNAIT]-(e2) 
        WHERE e.universite <> e2.universite | 
        e2.universite][0..2] AS exemples_connexions
ORDER BY nb_reseaux_pont DESC;

// ─── 4.4 : Analyse temporelle ─────────────────────────────────────────────
// Croissance du réseau : nouvelles connexions par mois

// Ajouter des propriétés temporelles sur les relations (simulation)
MATCH (e1:Etudiant)-[r:CONNAIT]->(e2:Etudiant)
WHERE r.depuis IS NULL
SET r.depuis = toString(2020 + rand() % 4) + "-" + 
               toString(1 + rand() % 12) + "-" + 
               toString(1 + rand() % 28);

// Analyse de la croissance mensuelle
MATCH (e1:Etudiant)-[r:CONNAIT]->(e2:Etudiant)
WHERE r.depuis IS NOT NULL
WITH split(r.depuis, "-")[0] AS annee, 
     split(r.depuis, "-")[1] AS mois,
     r
RETURN annee + "-" + mois AS periode,
       count(r) AS nouvelles_connexions,
       // Taux de croissance par université
       collect(DISTINCT e1.universite) AS universites_actives,
       // Connexions inter vs intra université
       sum(CASE WHEN e1.universite <> e2.universite THEN 1 ELSE 0 END) AS connexions_inter_universites,
       sum(CASE WHEN e1.universite = e2.universite THEN 1 ELSE 0 END) AS connexions_intra_universites
ORDER BY periode;

// Analyse des tendances de connexion par filière
MATCH (e1:Etudiant)-[r:CONNAIT]->(e2:Etudiant)
WHERE e1.filiere = e2.filiere
  AND r.depuis IS NOT NULL
WITH e1.filiere AS filiere,
     count(r) AS connexions_meme_filiere,
     avg(size((e1)-[:CONNAIT]-())) AS degre_moyen_filiere
RETURN filiere,
       connexions_meme_filiere,
       degre_moyen_filiere,
       // Comparaison avec la moyenne générale
       (connexions_meme_filiere * 100.0 / 
        (MATCH (x:Etudiant)-[:CONNAIT]-() RETURN count(*) / count(DISTINCT x))) AS pourcentage_vs_general
ORDER BY connexions_meme_filiere DESC;

// ─── 4.5 : Score de similarité ───────────────────────────────────────────────
// Étudiants les plus similaires à Ahmed (cours, compétences, clubs)
MATCH (cible:Etudiant {prenom: "Ahmed"})
WITH cible

// Similarité par cours communs
MATCH (cible)-[:SUIT]-(cours:Cours)
WITH cible, collect(cours.code) AS cours_cible

MATCH (autre:Etudiant)-[:SUIT]-(cours_autre:Cours)
WHERE autre <> cible
WITH autre, 
     size([c IN cours_cible WHERE c IN cours_autre.code]) AS cours_communs,
     size(cours_cible) AS total_cours_cible

// Similarité par compétences
MATCH (autre)-[:MAITRISE]-(comp_autre:Competence)
WITH autre, 
     cours_communs,
     total_cours_cible,
     collect(comp_autre.nom) AS competences_autre

MATCH (cible)-[:MAITRISE]-(comp_cible:Competence)
WITH autre, 
     cours_communs,
     total_cours_cible,
     competences_autre,
     collect(comp_cible.nom) AS competences_cible

// Similarité par clubs
MATCH (autre)-[:MEMBRE_DE]-(club_autre:Club)
WITH autre, 
     cours_communs,
     total_cours_cible,
     competences_autre,
     competences_cible,
     collect(club_autre.nom) AS clubs_autre

MATCH (cible)-[:MEMBRE_DE]-(club_cible:Club)
WITH autre, 
     cours_communs,
     total_cours_cible,
     competences_autre,
     competences_cible,
     clubs_autre,
     collect(club_cible.nom) AS clubs_cible

// Calculer le score de Jaccard pour chaque dimension
WITH autre,
     // Jaccard pour cours
     (size([c IN cours_communs WHERE c IN cours_autre.code]) * 1.0 / 
      size(cours_cible UNION cours_autre.code)) AS jaccard_cours,
     // Jaccard pour compétences
     (size([c IN competences_cible WHERE c IN competences_autre]) * 1.0 / 
      size(competences_cible UNION competences_autre)) AS jaccard_competences,
     // Jaccard pour clubs
     (size([c IN clubs_cible WHERE c IN clubs_autre]) * 1.0 / 
      size(clubs_cible UNION clubs_autre)) AS jaccard_clubs

// Score de similarité pondéré
RETURN autre.prenom + " " + autre.nom AS nom_similaire,
       autre.universite AS universite,
       autre.filiere AS filiere,
       // Similarités individuelles
       round(jaccard_cours, 3) AS similarite_cours,
       round(jaccard_competences, 3) AS similarite_competences,
       round(jaccard_clubs, 3) AS similarite_clubs,
       // Score global pondéré
       round(jaccard_cours * 0.4 + jaccard_competences * 0.4 + jaccard_clubs * 0.2, 3) AS score_global,
       // Détails des similarités
       size([c IN cours_communs WHERE c IN cours_autre.code]) AS nb_cours_communs,
       size([c IN competences_cible WHERE c IN competences_autre]) AS nb_competences_communes,
       size([c IN clubs_cible WHERE c IN clubs_autre]) AS nb_clubs_communs
ORDER BY score_global DESC
LIMIT 10;

// Nettoyage
CALL gds.graph.drop('reseau_social_etendu');
