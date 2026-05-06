"""
TP3 - Exercice 2 : Ingestion de données IoT
Use Case : SmartGrid DZ - 10 000 capteurs, 5 minutes de mesures
"""
from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
import uuid
import random
from datetime import datetime, timedelta
import time

# Configuration
CASSANDRA_HOST = 'localhost'
KEYSPACE = 'smartgrid'
NB_CAPTEURS = 10000
MINUTES_HISTORIQUE = 5

WILAYAS = ["Alger", "Oran", "Constantine", "Annaba", "Blida"]
COMMUNES = {
    "Alger": ["Bab Ezzouar", "Hydra", "El Harrach", "Dar El Beida"],
    "Oran": ["Bir El Djir", "Es Senia", "Arzew"],
    "Constantine": ["El Khroub", "Ain Smara", "Hamma Bouziane"],
    "Annaba": ["El Bouni", "El Hadjar", "Seraidi"],
    "Blida": ["Bougara", "Boufarik", "Larbaa"],
}

def connect():
    """Connexion au cluster Cassandra"""
    cluster = Cluster([CASSANDRA_HOST])
    session = cluster.connect(KEYSPACE)
    return session, cluster


def generate_mesure(capteur_id, wilaya, commune, timestamp):
    """Générer une mesure réaliste pour un capteur"""
    tension_base = 220  # Volts (réseau algérien)
    
    return {
        "capteur_id": capteur_id,
        "date_jour": timestamp.date(),
        "timestamp": timestamp,
        "wilaya": wilaya,
        "commune": commune,
        # Variation normale ± 10V
        "tension_v": round(tension_base + random.gauss(0, 5), 2),
        "courant_a": round(random.uniform(0.5, 15.0), 2),
        "puissance_kw": round(random.uniform(0.1, 3.3), 3),
        "frequence_hz": round(50 + random.gauss(0, 0.1), 2),
        "temperature": round(random.uniform(20, 65), 1),
        # 5% de chance d'alerte
        "alerte": random.random() < 0.05,
    }


def insert_single(session, mesure):
    """
    Insérer une seule mesure dans mesures_par_capteur
    Utiliser une prepared statement
    """
    query = session.prepare("""
        INSERT INTO mesures_par_capteur (
            capteur_id, date_jour, timestamp, wilaya, commune,
            tension_v, courant_a, puissance_kw, frequence_hz,
            temperature, alerte, code_alerte
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """)
    
    if mesure["alerte"]:
        code = random.choice(["SURTENSION", "SOUS_TENSION", "SURCHARGE", "PANNE"])
        mesure["code_alerte"] = code
    else:
        mesure["code_alerte"] = ""
    
    session.execute(query, [
        mesure["capteur_id"],
        mesure["date_jour"],
        mesure["timestamp"],
        mesure["wilaya"],
        mesure["commune"],
        mesure["tension_v"],
        mesure["courant_a"],
        mesure["puissance_kw"],
        mesure["frequence_hz"],
        mesure["temperature"],
        mesure["alerte"],
        mesure["code_alerte"]
    ])


def insert_batch(session, mesures: list):
    """
    Insérer un batch de mesures de manière efficace
    Utiliser UNLOGGED BATCH pour les séries temporelles
    Faire des batches de max 50 items (bonne pratique Cassandra)
    """
    query = session.prepare("""
        INSERT INTO mesures_par_capteur (
            capteur_id, date_jour, timestamp, wilaya, commune,
            tension_v, courant_a, puissance_kw, frequence_hz,
            temperature, alerte, code_alerte
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """)
    
    # Diviser en batches de 50
    batch_size = 50
    for i in range(0, len(mesures), batch_size):
        batch = mesures[i:i + batch_size]
        
        # Créer un batch UNLOGGED pour les séries temporelles
        batch_stmt = BatchStatement(BatchType.UNLOGGED)
        
        for mesure in batch:
            if mesure["alerte"]:
                code = random.choice(["SURTENSION", "SOUS_TENSION", "SURCHARGE", "PANNE"])
                mesure["code_alerte"] = code
            else:
                mesure["code_alerte"] = ""
            
            batch_stmt.add(query, [
                mesure["capteur_id"],
                mesure["date_jour"],
                mesure["timestamp"],
                mesure["wilaya"],
                mesure["commune"],
                mesure["tension_v"],
                mesure["courant_a"],
                mesure["puissance_kw"],
                mesure["frequence_hz"],
                mesure["temperature"],
                mesure["alerte"],
                mesure["code_alerte"]
            ])
        
        session.execute(batch_stmt)
        print(f"  Batch {i//batch_size + 1}: {len(batch)} mesures insérées")


def run_ingestion(session):
    """
    Générer et insérer NB_CAPTEURS × MINUTES_HISTORIQUE mesures
    1. Générer les capteurs (ID aléatoires + assignation wilaya/commune)
    2. Pour chaque minute des MINUTES_HISTORIQUE dernières minutes
       → Insérer les mesures de tous les capteurs
    3. Mesurer et afficher :
       - Nombre total d'insertions
       - Durée totale
       - Débit (mesures/seconde)
    """
    print(f"Démarrage ingestion : {NB_CAPTEURS} capteurs × {MINUTES_HISTORIQUE} min")
    start = time.time()
    
    # 1. Générer les capteurs
    capteurs = []
    for i in range(NB_CAPTEURS):
        wilaya = random.choice(WILAYAS)
        commune = random.choice(COMMUNES[wilaya])
        capteur_id = uuid.uuid4()
        capteurs.append({
            "id": capteur_id,
            "wilaya": wilaya,
            "commune": commune
        })
    
    print(f"  {NB_CAPTEURS} capteurs générés")
    
    # 2. Générer et insérer les mesures
    now = datetime.now()
    all_mesures = []
    
    for minute_offset in range(MINUTES_HISTORIQUE):
        timestamp = now - timedelta(minutes=minute_offset)
        
        minute_mesures = []
        for capteur in capteurs:
            mesure = generate_mesure(
                capteur["id"], 
                capteur["wilaya"], 
                capteur["commune"], 
                timestamp
            )
            minute_mesures.append(mesure)
        
        # Insérer par batch de 50
        insert_batch(session, minute_mesures)
        all_mesures.extend(minute_mesures)
        
        if (minute_offset + 1) % 10 == 0:
            print(f"  {minute_offset + 1}/{MINUTES_HISTORIQUE} minutes traitées")
    
    elapsed = time.time() - start
    total = len(all_mesures)
    
    print(f"\n✅ {total:,} mesures insérées en {elapsed:.1f}s")
    print(f"   Débit : {total/elapsed:,.0f} mesures/seconde")
    print(f"   Moyenne : {elapsed/total*1000:.2f}ms/mesure")
    
    # 3. Insérer quelques alertes dans la table dédiée
    alertes = [m for m in all_mesures if m["alerte"]][:100]  # Limiter à 100 alertes
    
    alert_query = session.prepare("""
        INSERT INTO alertes_par_wilaya (
            wilaya, date_jour, timestamp, capteur_id,
            code_alerte, description, gravite, resolue
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """)
    
    for alerte in alertes:
        gravite = random.choice([1, 2, 3])
        descriptions = {
            "SURTENSION": "Tension supérieure à 240V",
            "SOUS_TENSION": "Tension inférieure à 200V",
            "SURCHARGE": "Puissance supérieure à 3kW",
            "PANNE": "Capteur non répondant"
        }
        
        session.execute(alert_query, [
            alerte["wilaya"],
            alerte["date_jour"],
            alerte["timestamp"],
            alerte["capteur_id"],
            alerte["code_alerte"],
            descriptions.get(alerte["code_alerte"], "Alerte inconnue"),
            gravite,
            False
        ])
    
    print(f"   {len(alertes)} alertes insérées")


if __name__ == "__main__":
    session, cluster = connect()
    run_ingestion(session)
    cluster.shutdown()
