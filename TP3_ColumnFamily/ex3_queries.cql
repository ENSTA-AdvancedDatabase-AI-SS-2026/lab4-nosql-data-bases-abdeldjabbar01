-- TP3 - Exercice 3 : Requêtes CQL Avancées
-- Use Case : SmartGrid DZ - Analyse des données IoT

USE smartgrid;

-- ─── 3.1 : Mesures d'un capteur spécifique sur les 6 dernières heures ─────
-- Requête cible : "Toutes les mesures du capteur X entre T1 et T2"
SELECT * FROM mesures_par_capteur 
WHERE capteur_id = ? AND date_jour = ? AND timestamp >= ? 
LIMIT 100;

-- Exemple pratique :
-- SELECT * FROM mesures_par_capteur 
-- WHERE capteur_id = 123e4567-e89b-12d3-a456-426614174000 
--   AND date_jour = '2024-03-15' 
--   AND timestamp >= '2024-03-15 10:00:00';

-- ─── 3.2 : Dernière mesure de chaque capteur d'une wilaya ─────────────────
-- Astuce : utiliser LIMIT 1 avec clustering DESC
-- Note : Cette requête nécessite une table optimisée

-- Créer une vue matérialisée pour cette requête
CREATE MATERIALIZED VIEW IF NOT EXISTS derniere_mesure_par_wilaya AS
SELECT wilaya, capteur_id, timestamp, tension_v, courant_a, puissance_kw
FROM mesures_par_capteur
WHERE timestamp IS NOT NULL
PRIMARY KEY (wilaya, capteur_id, timestamp);

-- Requête pour obtenir la dernière mesure par capteur
SELECT * FROM derniere_mesure_par_wilaya 
WHERE wilaya = 'Alger';

-- Alternative avec GROUP BY (moins performant)
SELECT wilaya, capteur_id, 
       max(timestamp) as derniere_mesure,
       max(tension_v) as derniere_tension
FROM mesures_par_capteur 
WHERE wilaya = 'Alger' AND date_jour = currentdate()
GROUP BY wilaya, capteur_id;

-- ─── 3.3 : Capteurs en alerte dans la wilaya "Alger" aujourd'hui ───────
SELECT count(*) as nb_alertes, 
       collect_set(code_alerte) as types_alertes
FROM alertes_par_wilaya 
WHERE wilaya = 'Alger' 
  AND date_jour = currentdate();

-- Détail des alertes
SELECT timestamp, capteur_id, code_alerte, description, gravite
FROM alertes_par_wilaya 
WHERE wilaya = 'Alger' 
  AND date_jour = currentdate()
ORDER BY timestamp DESC
LIMIT 50;

-- ─── 3.4 : Consommation totale par heure sur une journée (dashboard) ───────
-- Utiliser la table d'agrégats pré-calculés
SELECT dateheure as heure, 
       nb_capteurs,
       puissance_moy_kw,
       puissance_max_kw,
       puissance_min_kw,
       nb_alertes
FROM agregats_horaires 
WHERE wilaya = 'Alger' 
  AND dateheure >= '2024-03-15 00:00:00'
  AND dateheure < '2024-03-16 00:00:00'
ORDER BY dateheure ASC;

-- Si besoin de calculer à la volée (moins performant)
SELECT dateof(timestamp) as jour,
       hour(timestamp) as heure,
       count(*) as nb_mesures,
       avg(puissance_kw) as puissance_moyenne,
       max(puissance_kw) as puissance_max,
       min(puissance_kw) as puissance_min
FROM mesures_par_capteur 
WHERE wilaya = 'Alger' 
  AND date_jour = '2024-03-15'
GROUP BY dateof(timestamp), hour(timestamp)
ORDER BY heure ASC;

-- ─── 3.5 : Détection d'anomalie : capteurs avec tension hors normes ───────
-- Tension < 200V ou > 240V dans les 30 dernières minutes
SELECT capteur_id, wilaya, timestamp, tension_v, code_alerte
FROM mesures_par_capteur 
WHERE (tension_v < 200 OR tension_v > 240)
  AND timestamp >= dateof(now()) - 30 * 60
  AND date_jour = currentdate()
ORDER BY timestamp DESC
LIMIT 100;

-- Capteurs avec anomalies fréquentes (plus de 5 anomalies aujourd'hui)
SELECT capteur_id, wilaya, count(*) as nb_anomalies
FROM mesures_par_capteur 
WHERE (tension_v < 200 OR tension_v > 240)
  AND date_jour = currentdate()
GROUP BY capteur_id, wilaya
HAVING count(*) > 5
ORDER BY nb_anomalies DESC;

-- ─── 3.6 : Top 10 capteurs les plus actifs cette semaine ───────────────
SELECT capteur_id, wilaya, count(*) as nb_mesures
FROM mesures_par_capteur 
WHERE date_jour >= dateof(now()) - 7 * 24 * 60 * 60
GROUP BY capteur_id, wilaya
ORDER BY nb_mesures DESC
LIMIT 10;

-- Top 10 par wilaya
SELECT wilaya, capteur_id, count(*) as nb_mesures
FROM mesures_par_capteur 
WHERE date_jour >= dateof(now()) - 7 * 24 * 60 * 60
GROUP BY wilaya, capteur_id
ORDER BY wilaya, nb_mesures DESC;

-- ─── 3.7 : Requête ALLOW FILTERING - Pourquoi éviter ? ───────────────
-- MAUVAISE : Utiliser ALLOW FILTERING
-- Cette requête est DANGEREUSE en production
SELECT * FROM mesures_par_capteur 
WHERE puissance_kw > 2.5 
  AND date_jour = '2024-03-15'
ALLOW FILTERING;

-- PROBLÈMES :
-- 1. Scan complet de la partition (très lent)
-- 2. Ne peut pas utiliser d'index sur puissance_kw
-- 3. Consomme beaucoup de ressources CPU/mémoire
-- 4. Timeout sur gros volumes de données

-- BONNE : Créer une table optimisée pour ce type de requête
CREATE TABLE IF NOT EXISTS mesures_par_puissance (
  wilaya TEXT,
  date_jour DATE,
  puissance_range TEXT,  -- 'faible', 'moyenne', 'eleve'
  capteur_id UUID,
  timestamp TIMESTAMP,
  tension_v FLOAT,
  courant_a FLOAT,
  puissance_kw FLOAT,
  PRIMARY KEY ((wilaya, puissance_range, date_jour), timestamp DESC)
);

-- Ou utiliser une requête plus sélective
SELECT * FROM mesures_par_capteur 
WHERE wilaya = 'Alger' 
  AND date_jour = '2024-03-15'
  AND timestamp >= '2024-03-15 00:00:00'
  AND timestamp < '2024-03-15 23:59:59';

-- Requêtes de monitoring et statistiques additionnelles

-- Statistiques horaires par wilaya
SELECT wilaya, 
       hour(timestamp) as heure,
       avg(tension_v) as tension_moyenne,
       avg(puissance_kw) as puissance_moyenne,
       count(*) as nb_mesures
FROM mesures_par_capteur 
WHERE date_jour = currentdate()
GROUP BY wilaya, hour(timestamp)
ORDER BY wilaya, heure;

-- Taux d'alertes par wilaya aujourd'hui
SELECT a.wilaya, 
       count(*) as nb_alertes,
       (count(*) * 100.0 / (SELECT count(*) FROM mesures_par_capteur m 
                              WHERE m.wilaya = a.wilaya 
                                AND m.date_jour = currentdate())) as taux_alerte_pct
FROM alertes_par_wilaya a
WHERE a.date_jour = currentdate()
GROUP BY a.wilaya;

-- Capteurs avec le plus d'alertes (derniers 7 jours)
SELECT capteur_id, wilaya, count(*) as nb_alertes
FROM alertes_par_wilaya 
WHERE date_jour >= dateof(now()) - 7 * 24 * 60 * 60
GROUP BY capteur_id, wilaya
ORDER BY nb_alertes DESC
LIMIT 20;

-- Vérification des performances
EXPLAIN PLAN 
SELECT * FROM mesures_par_capteur 
WHERE capteur_id = ? AND date_jour = ? AND timestamp >= ?;
