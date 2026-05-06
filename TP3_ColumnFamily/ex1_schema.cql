// TP3 - Exercice 1 : Schema Cassandra
// Use Case : SmartGrid DZ - IoT Electrique

// Create keyspace 'smartgrid' with NetworkTopologyStrategy
// replication_factor: 3 (for production), 1 (for local TP)

CREATE KEYSPACE smartgrid
WITH replication = { 'class': 'NetworkTopologyStrategy', 'datacenter1': 1 };

USE smartgrid;

// Table mesures_par_capteur
// Target query: "Measures of sensor X between T1 and T2"
// TODO: Define the correct PRIMARY KEY
// Think: how to avoid hot partitions with 10,000 sensors?
-- Penser : comment éviter les hot partitions avec 10 000 capteurs ?

CREATE TABLE IF NOT EXISTS mesures_par_capteur (
  capteur_id   UUID,
  date_jour    DATE,  -- Ajout pour éviter les hot partitions
  timestamp    TIMESTAMP,
  wilaya       TEXT,
  commune      TEXT,
  tension_v    FLOAT,
  courant_a    FLOAT,
  puissance_kw FLOAT,
  frequence_hz FLOAT,
  temperature  FLOAT,
  alerte       BOOLEAN,
  code_alerte  TEXT,
  PRIMARY KEY ((capteur_id, date_jour), timestamp DESC)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000;  -- 90 jours en secondes


-- ─── 1.3 : Table alertes_par_wilaya ───────────────────────────────────────────
-- Requête cible : "Alertes de la wilaya X le jour Y"
-- TODO: Concevoir la table

CREATE TABLE IF NOT EXISTS alertes_par_wilaya (
  wilaya       TEXT,
  date_jour    DATE,
  timestamp    TIMESTAMP,
  capteur_id   UUID,
  code_alerte  TEXT,
  description  TEXT,
  gravite      INT,   -- 1=info, 2=warning, 3=critique
  resolue      BOOLEAN,
  PRIMARY KEY ((wilaya, date_jour), timestamp DESC)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 31536000;  -- 1 an


-- ─── 1.4 : Table agregats_horaires ────────────────────────────────────────────
-- Requête cible : "Consommation moyenne par heure pour le dashboard wilaya"
-- TODO: Concevoir la table avec les bonnes agrégations

CREATE TABLE IF NOT EXISTS agregats_horaires (
  wilaya            TEXT,
  date_heure        TIMESTAMP,  -- Arrondi à l'heure
  nb_capteurs       INT,
  puissance_moy_kw  FLOAT,
  puissance_max_kw  FLOAT,
  puissance_min_kw  FLOAT,
  nb_alertes        INT,
  PRIMARY KEY ((wilaya, date_heure))
) WITH CLUSTERING ORDER BY (date_heure DESC)
  AND default_time_to_live = 157680000;  -- 5 ans


-- Vérification
DESCRIBE TABLES;
