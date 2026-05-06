-- TP3 - Exercice 4 : Compaction et Maintenance Cassandra
-- Use Case : SmartGrid DZ - Optimisation des séries temporelles

USE smartgrid;

-- ─── 4.1 : Choisir la stratégie de compaction pour chaque table ───────

-- Table mesures_par_capteur : TimeWindowCompactionStrategy (TWCS)
-- Justification : Séries temporelles avec ingestion continue
-- Avantages TWCS pour IoT :
--   - Regroupe les données par fenêtres temporelles
--   - Optimisé pour les requêtes par plage temporelle
--   - Nettoie automatiquement les anciennes données
ALTER TABLE mesures_par_capteur 
WITH compaction = {
  'class': 'TimeWindowCompactionStrategy',
  'compaction_window_unit': 'HOURS',
  'compaction_window_size': '6'
};

-- Table alertes_par_wilaya : SizeTieredCompactionStrategy (STCS)
-- Justification : Alertes moins fréquentes, lecture aléatoire
-- Avantages STCS pour alertes :
--   - Bon pour les charges d'écriture intermittentes
--   - Maintient plusieurs tailles de SSTables
--   - Optimisé pour les lectures ponctuelles
ALTER TABLE alertes_par_wilaya 
WITH compaction = {
  'class': 'SizeTieredCompactionStrategy',
  'min_sstable_size': '50MB'
};

-- Table agregats_horaires : LeveledCompactionStrategy (LCS)
-- Justification : Données pré-agrégées, mises à jour périodiquement
-- Avantages LCS pour agrégats :
--   - Excellente performance en lecture
--   - Pas de duplication de données
--   - Idéal pour les données qui changent peu
ALTER TABLE agregats_horaires 
WITH compaction = {
  'class': 'LeveledCompactionStrategy',
  'sstable_size_in_mb': '160'
};

-- ─── 4.2 : Configurer TWCS pour les mesures ───────────────────────────

-- Configuration optimisée pour 10 000 mesures/minute
-- Fenêtre de 6 heures = 6 * 60 * 10 000 = 3.6M de données par fenêtre
ALTER TABLE mesures_par_capteur 
WITH compaction = {
  'class': 'TimeWindowCompactionStrategy',
  'compaction_window_unit': 'HOURS',
  'compaction_window_size': '6',
  'timestamp_resolution': 'MICROSECONDS'
};

-- Justification des paramètres :
-- - 6 heures : Bon équilibre entre performance et taille des SSTables
-- - MICROSECONDS : Précision nécessaire pour les séries temporelles
-- - Fenêtre plus large = meilleure compression mais plus de mémoire

-- ─── 4.3 : Vérifier l'utilisation des TTL ───────────────────────────

-- Requête pour voir combien de lignes expirent dans les 7 prochains jours
SELECT 
  wilaya,
  count(*) as total_mesures,
  count(*) - sum(CASE WHEN ttl(timestamp) > 7*24*3600 THEN 1 ELSE 0 END) as expirant_7j,
  sum(CASE WHEN ttl(timestamp) <= 7*24*3600 THEN 1 ELSE 0 END) as expirant_soon_7j,
  min(ttl(timestamp)) as ttl_min_heures,
  max(ttl(timestamp)) as ttl_max_heures
FROM mesures_par_capteur 
WHERE date_jour >= currentdate() - 30
GROUP BY wilaya;

-- TTL par table
SELECT 
  'mesures_par_capteur' as table_name,
  90 as ttl_jours,
  'Données brutes IoT' as description
UNION ALL SELECT 
  'alertes_par_wilaya' as table_name,
  365 as ttl_jours,
  'Alertes et incidents' as description
UNION ALL SELECT 
  'agregats_horaires' as table_name,
  1825 as ttl_jours,
  'Agrégats pré-calculés' as description;

-- Monitoring de l'espace libéré par TTL
SELECT 
  keyspace_name,
  table_name,
  size_on_disk_mb,
  estimated_ttl_space_saved_mb,
  ttl_saving_percentage
FROM system_schema.tables 
WHERE keyspace_name = 'smartgrid';

-- ─── 4.4 : Analyser une partition "hot" ─────────────────────────────

-- Détection des partitions les plus volumineuses
SELECT 
  wilaya,
  date_jour,
  count(*) as nb_mesures,
  sum(tension_v * courant_a) as energie_totale,
  max(timestamp) as derniere_mesure
FROM mesures_par_capteur 
WHERE date_jour >= currentdate() - 7
GROUP BY wilaya, date_jour
ORDER BY nb_mesures DESC
LIMIT 20;

-- Détection des capteurs les plus actifs (potentiels hot partitions)
SELECT 
  capteur_id,
  wilaya,
  count(*) as nb_mesures_24h,
  avg(puissance_kw) as puissance_moyenne,
  max(puissance_kw) as puissance_max
FROM mesures_par_capteur 
WHERE timestamp >= dateof(now()) - 24*60*60
GROUP BY capteur_id, wilaya
HAVING count(*) > 1000  -- Plus de 1000 mesures en 24h = suspect
ORDER BY nb_mesures_24h DESC
LIMIT 10;

-- Solutions pour corriger les hot partitions :

-- 1. Ajouter un bucket temporel supplémentaire (déjà fait avec date_jour)
--    Avantages : Répartit la charge sur plusieurs partitions
--    Inconvénients : Requêtes plus complexes

-- 2. Utiliser une table de répartition (sharding manuel)
CREATE TABLE IF NOT EXISTS mesures_sharded (
  shard_key INT,  -- 0-9 pour répartir 10 000 capteurs
  capteur_id UUID,
  date_jour DATE,
  timestamp TIMESTAMP,
  wilaya TEXT,
  commune TEXT,
  tension_v FLOAT,
  courant_a FLOAT,
  puissance_kw FLOAT,
  PRIMARY KEY ((shard_key, capteur_id, date_jour), timestamp DESC)
);

-- Calcul du shard_key : hash(capteur_id) % 10
-- Répartit uniformément les capteurs sur 10 shards

-- 3. Partitionnement par type de capteur
CREATE TABLE IF NOT EXISTS mesures_par_type (
  type_capteur TEXT,  -- 'residentiel', 'industriel', 'public'
  capteur_id UUID,
  date_jour DATE,
  timestamp TIMESTAMP,
  wilaya TEXT,
  puissance_kw FLOAT,
  PRIMARY KEY ((type_capteur, capteur_id, date_jour), timestamp DESC)
);

-- ─── Maintenance et monitoring additionnels ─────────────────────────────────

-- Statistiques de compaction
SELECT 
  keyspace_name,
  table_name,
  compaction_parameters,
  pending_compactions,
  sstable_count
FROM system_schema.tables 
WHERE keyspace_name = 'smartgrid';

-- Espace disque par table
SELECT 
  keyspace_name,
  table_name,
  sum(disk_space) as total_space_mb
FROM system_schema.sstable_statistics 
WHERE keyspace_name = 'smartgrid'
GROUP BY keyspace_name, table_name;

-- Performance des requêtes récentes
SELECT 
  command,
  keyspace_name,
  table_name,
  count(*) as executions,
  avg(coordinator_latency_ms) as avg_latency_ms,
  p95_coordinator_latency_ms,
  p99_coordinator_latency_ms
FROM system_schema.query_metrics 
WHERE keyspace_name = 'smartgrid'
  AND timestamp >= dateof(now()) - 24*60*60
GROUP BY command, keyspace_name, table_name
ORDER BY avg_latency_ms DESC;

-- Recommandations de maintenance :

-- Pour TWCS (mesures_par_capteur) :
-- - Surveiller la taille des fenêtres de 6 heures
-- - Ajuster si les SSTables deviennent trop grosses
-- - Considérer 12 heures si la compression est mauvaise

-- Pour STCS (alertes_par_wilaya) :
-- - Surveiller le nombre de SSTables (trop = fragmentation)
-- - Lancer nodetool compact si nécessaire
-- - Considérer LCS si les lectures deviennent lentes

-- Pour LCS (agregats_horaires) :
-- - Surveillance de l'espace disque (pas de TTL)
-- - Compactation manuelle périodique si nécessaire
-- - Archive des anciens agrégats

-- Script de maintenance automatisé recommandé :
-- 1. Vérification quotidienne des hot partitions
-- 2. Nettoyage hebdomadaire des snapshots
-- 3. Analyse mensuelle des performances de compaction
-- 4. Ajustement trimestriel des paramètres TWCS
