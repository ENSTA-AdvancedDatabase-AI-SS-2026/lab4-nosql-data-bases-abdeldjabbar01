// TP4 - Exercice 3 : Algorithmes de Graphe avec GDS
// Prérequis : Plugin Graph Data Science installé (inclus dans docker-compose)

// ─── 3.1 : Plus court chemin ──────────────────────────────────────────────────
// "Comment Ahmed peut-il rencontrer Yasmina ?"
MATCH p = shortestPath(
  (a:Etudiant {prenom: "Ahmed"})-[:CONNAIT*..10]-(b:Etudiant {prenom: "Yasmina"})
)
RETURN [n IN nodes(p) | n.prenom + " (" + n.universite + ")"] AS chemin,
       length(p) AS nb_intermediaires;


// ─── 3.2 : Centralité de degré ────────────────────────────────────────────────
// Créer la projection du graphe en mémoire
CALL gds.graph.project(
  'reseau_social',
  'Etudiant',
  'CONNAIT'
);

// 3.2 : Centralité de degré
// Créer la projection du graphe en mémoire
CALL gds.graph.project(
  'reseau_social',
  'Etudiant',
  'CONNAIT'
);

// Calculer et afficher le top 10 des étudiants les plus connectés
CALL gds.degree.stream('reseau_social')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).prenom AS etudiant,
       gds.util.asNode(nodeId).universite AS universite,
       score AS nb_connexions
ORDER BY score DESC
LIMIT 10;


// ─── 3.3 : Détection de communautés (Louvain) ────────────────────────────────
// 3.3 : Détection de communautés (Louvain)
CALL gds.louvain.stream('reseau_social')
YIELD nodeId, communityId
WITH communityId, collect(gds.util.asNode(nodeId).prenom) AS membres
RETURN communityId,
       size(membres) AS taille,
       membres[0..5] AS exemple_membres
ORDER BY taille DESC;


// ─── 3.4 : Recommandation de contacts ────────────────────────────────────────
// "Qui Ahmed devrait-il connaître ?" 
// Critères : amis en commun + même cours + même filière

// 3.4 : Recommandation de contacts
MATCH (moi:Etudiant {prenom: "Ahmed"})
WITH moi

// Amis d'amis (2 sauts maximum)
MATCH (moi)-[:CONNAIT*1..2]-(potentiel:Etudiant)
WHERE NOT (moi)-[:CONNAIT]-(potentiel)

WITH potentiel, 
     // Calculer les critères de similarité
     size((moi)-[:CONNAIT]-(potentiel)) AS amis_communs,
     size((moi)-[:SUIT]-(:Cours)<-(:SUIT]-(potentiel)) AS cours_communs,
     CASE WHEN moi.filiere = potentiel.filiere THEN 1 ELSE 0 END AS meme_filiere

// Calculer le score de recommandation
WITH potentiel,
     amis_communs * 3 + cours_communs * 2 + meme_filiere AS score

RETURN 
  potentiel.prenom + " " + potentiel.nom AS suggestion,
  potentiel.universite AS universite,
  potentiel.filiere AS filiere,
  amis_communs,
  cours_communs,
  meme_filiere,
  score
ORDER BY score DESC
LIMIT 5;


// ─── 3.5 : Chemin de compétences ─────────────────────────────────────────────
// "Quels cours mènent à Machine Learning ?"
MATCH path = (debut:Cours)-[:REQUIERT*]->(but:Competence {nom: "Machine Learning"})
RETURN [n IN nodes(path) | 
  CASE WHEN n:Cours THEN n.intitule ELSE n.nom END
] AS parcours_apprentissage;


// Nettoyage
CALL gds.graph.drop('reseau_social');
