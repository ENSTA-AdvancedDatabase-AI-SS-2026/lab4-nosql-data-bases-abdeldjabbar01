// TP4 - Exercice 1 : Creation du graphe UniConnect DZ
// Effacer la base pour partir propre
MATCH (n) DETACH DELETE n;

// 1.1 : Contraintes d'unicite
CREATE CONSTRAINT etudiant_id IF NOT EXISTS FOR (e:Etudiant) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT cours_code IF NOT EXISTS FOR (c:Cours) REQUIRE c.code IS UNIQUE;
CREATE CONSTRAINT competence_nom IF NOT EXISTS FOR (c:Competence) REQUIRE c.nom IS UNIQUE;

// 1.2 : Creer les competences
UNWIND [
  {nom: "Python", categorie: "Programmation"},
  {nom: "Java", categorie: "Programmation"},
  {nom: "SQL", categorie: "Bases de Données"},
  {nom: "NoSQL", categorie: "Bases de Données"},
  {nom: "Machine Learning", categorie: "IA"},
  {nom: "Deep Learning", categorie: "IA"},
  {nom: "React", categorie: "Web"},
  {nom: "Docker", categorie: "DevOps"},
  {nom: "Linux", categorie: "Systèmes"},
  {nom: "Réseaux", categorie: "Infrastructure"}
] AS comp
MERGE (:Competence {nom: comp.nom, categorie: comp.categorie});

// 1.3 : Creer les cours
UNWIND [
  {code: "INFO401", intitule: "Bases de Données Avancées", credits: 6, dept: "Informatique"},
  {code: "INFO402", intitule: "Intelligence Artificielle", credits: 6, dept: "Informatique"},
  {code: "INFO403", intitule: "Développement Web", credits: 4, dept: "Informatique"},
  {code: "INFO404", intitule: "Systèmes Distribués", credits: 5, dept: "Informatique"},
  {code: "INFO405", intitule: "Cloud Computing", credits: 4, dept: "Informatique"}
] AS cours
MERGE (:Cours {code: cours.code, intitule: cours.intitule, 
               credits: cours.credits, departement: cours.dept});

// ─── 1.4 : Créer les étudiants ────────────────────────────────────────────────
UNWIND range(1, 51) AS i
WITH 
  ['Ahmed', 'Mohamed', 'Karim', 'Yacine', 'Rachid', 'Abdelkader', 'Brahim', 'Sofiane', 'Walid', 'Nabil'] AS prenomsM,
  ['Fatima', 'Aicha', 'Khadija', 'Samiha', 'Nadia', 'Lila', 'Meriem', 'Yasmina', 'Imane', 'Zohra'] AS prenomsF,
  ['Bensalem', 'Kaci', 'Cherif', 'Haddad', 'Boudiaf', 'Zerrouki', 'Mansouri', 'Benali', 'Hadj', 'Kaci'] AS noms,
  ['USTHB', 'UMBB', 'USTO', 'UMC', 'UBMA'] AS universites,
  ['Informatique', 'Mathématiques', 'Electronique', 'Télécoms', 'Génie Civil'] AS filieres
MERGE (e:Etudiant {id: 'E' + toString(i)})
SET 
  e.prenom = i % 2 = 0 ? prenomsM[i % 10] : prenomsF[i % 10],
  e.nom = noms[i % 10],
  e.universite = universites[i % 5],
  e.filiere = filieres[i % 5],
  e.annee = (i % 4) + 1,
  e.ville = CASE e.universite 
    WHEN 'USTHB' THEN 'Alger'
    WHEN 'UMBB' THEN 'Boumerdes'
    WHEN 'USTO' THEN 'Oran'
    WHEN 'UMC' THEN 'Tizi Ouzou'
    WHEN 'UBMA' THEN 'Annaba'
  END;

// ─── 1.5 : Créer les relations ────────────────────────────────────────────────

// Relations CONNAIT (créer un réseau social connecté)
MATCH (e1:Etudiant), (e2:Etudiant)
WHERE e1 <> e2 
  AND e1.universite = e2.universite
  AND random() < 0.15  // 15% de chance de connexion
MERGE (e1)-[r:CONNAIT {depuis: toString(2020 + rand() % 4), contexte: 'université'}]->(e2);

// Connexions inter-universités (plus rares)
MATCH (e1:Etudiant), (e2:Etudiant)
WHERE e1 <> e2 
  AND e1.universite <> e2.universite
  AND e1.filiere = e2.filiere
  AND random() < 0.05  // 5% de chance
MERGE (e1)-[r:CONNAIT {depuis: toString(2021 + rand() % 3), contexte: 'forum'}]->(e2);

// Relations SUIT (étudiant → cours)
MATCH (e:Etudiant), (c:Cours)
WHERE e.filiere = 'Informatique' AND c.code IN ['INFO401', 'INFO402', 'INFO403']
  AND random() < 0.7
MERGE (e)-[r:SUIT {semestre: 'S' + toString((rand() % 4) + 1), note: 10 + rand() * 10}]->(c);

MATCH (e:Etudiant), (c:Cours)
WHERE e.filiere IN ['Mathématiques', 'Electronique'] AND c.code IN ['INFO401', 'INFO404']
  AND random() < 0.6
MERGE (e)-[r:SUIT {semestre: 'S' + toString((rand() % 4) + 1), note: 8 + rand() * 12}]->(c);

// Relations MAITRISE (étudiant → compétence)
MATCH (e:Etudiant), (comp:Competence)
WHERE e.filiere = 'Informatique' 
  AND comp.categorie IN ['Programmation', 'Bases de Données', 'DevOps']
  AND random() < 0.8
MERGE (e)-[r:MAITRISE {niveau: CASE comp.nom
  WHEN 'Python' THEN 'Avancé'
  WHEN 'Java' THEN 'Intermédiaire'
  WHEN 'SQL' THEN 'Avancé'
  WHEN 'React' THEN 'Intermédiaire'
  ELSE 'Débutant' END}]->(comp);

MATCH (e:Etudiant), (comp:Competence)
WHERE e.filiere IN ['Mathématiques', 'Electronique'] 
  AND comp.categorie IN ['Systèmes', 'Infrastructure']
  AND random() < 0.6
MERGE (e)-[r:MAITRISE {niveau: 'Intermédiaire'}]->(comp);

// Vérification
MATCH (n) RETURN labels(n)[0] AS type, count(n) AS total ORDER BY total DESC;
MATCH ()-[r]->() RETURN type(r) AS relation, count(r) AS total ORDER BY total DESC;
