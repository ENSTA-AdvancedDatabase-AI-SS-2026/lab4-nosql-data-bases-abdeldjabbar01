// TP5 - Benchmark Comparatif NoSQL
// Mesurer les performances de Redis, MongoDB, Cassandra, Neo4j
import time
import statistics
import json
from typing import Callable, List, Tuple
import redis
from pymongo import MongoClient
from cassandra.cluster import Cluster
from neo4j import GraphDatabase

// Utilitaires de mesure

def measure_latency(fn, iterations=1000):
    """
    Executer fn iterations fois et retourner les statistiques
    """
    latencies = []
    for _ in range(iterations):
        start = time.perf_counter()
        fn()
        latencies.append((time.perf_counter() - start) * 1000)  # en ms
    
    latencies.sort()
    return {
        "mean_ms": statistics.mean(latencies),
        "p50_ms": latencies[int(0.50 * len(latencies))],
        "p95_ms": latencies[int(0.95 * len(latencies))],
        "p99_ms": latencies[int(0.99 * len(latencies))],
        "max_ms": max(latencies),
        "throughput_rps": 1000 / statistics.mean(latencies)
    }


def print_results(name: str, results: dict):
    print(f"\n{'='*50}")
    print(f" {name}")
    print(f"{'='*50}")
    for k, v in results.items():
        print(f"  {k:20s}: {v:.2f}")


# ─── Ex1 : Benchmark Écriture ─────────────────────────────────────────────────

def benchmark_write_redis(n: int = 100_000):
    """Insérer n enregistrements dans Redis et mesurer le débit"""
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    # Préparer les données
    data = []
    for i in range(n):
        data.append({
            f"product:{i}": json.dumps({
                "id": i,
                "name": f"Product {i}",
                "price": float(i * 10),
                "category": ["electronics", "books", "clothing"][i % 3]
            })
        })
    
    # Utiliser un pipeline pour maximiser le débit
    start = time.perf_counter()
    
    # Diviser en batches de 1000
    batch_size = 1000
    for i in range(0, len(data), batch_size):
        batch = data[i:i + batch_size]
        pipe = r.pipeline()
        for item in batch.items():
            for key, value in item.items():
                pipe.set(key, value)
        pipe.execute()
        
        if (i + batch_size) % 10000 == 0:
            print(f"  Redis: {min(i + batch_size, n):,}/{n:,} écritures")
    
    elapsed = time.perf_counter() - start
    throughput = n / elapsed
    
    print(f"\nRedis Écriture:")
    print(f"  Temps: {elapsed:.2f}s")
    print(f"  Débit: {throughput:.0f} opérations/seconde")
    print(f"  Latence moyenne: {elapsed/n*1000:.2f}ms")
    
    return {"throughput_rps": throughput, "avg_latency_ms": elapsed/n*1000}


def benchmark_write_mongodb(n: int = 100_000):
    """Insérer n documents dans MongoDB et mesurer le débit"""
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    db = client["benchmark"]
    
    # Préparer les documents
    documents = []
    for i in range(n):
        documents.append({
            "_id": i,
            "sensor_id": f"sensor_{i % 1000}",
            "timestamp": time.time(),
            "value": float(i * 0.1),
            "location": {
                "city": ["Alger", "Oran", "Constantine"][i % 3],
                "coordinates": [float(i % 100), float(i % 50)]
            },
            "metadata": {
                "type": ["temperature", "pressure", "humidity"][i % 3],
                "quality": "good" if i % 10 != 0 else "bad"
            }
        })
    
    # Utiliser insert_many pour le débit maximal
    start = time.perf_counter()
    
    # Diviser en batches de 10000
    batch_size = 10000
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        db.benchmark.insert_many(batch, ordered=False)
        
        if (i + batch_size) % 50000 == 0:
            print(f"  MongoDB: {min(i + batch_size, n):,}/{n:,} documents")
    
    elapsed = time.perf_counter() - start
    throughput = n / elapsed
    
    print(f"\nMongoDB Écriture:")
    print(f"  Temps: {elapsed:.2f}s")
    print(f"  Débit: {throughput:.0f} documents/seconde")
    print(f"  Latence moyenne: {elapsed/n*1000:.2f}ms")
    
    client.close()
    return {"throughput_rps": throughput, "avg_latency_ms": elapsed/n*1000}


def benchmark_write_cassandra(n: int = 100_000):
    """Insérer n rows dans Cassandra et mesurer le débit"""
    cluster = Cluster(['localhost'])
    session = cluster.connect('benchmark')
    
    # Créer la table si elle n'existe pas
    session.execute("""
        CREATE TABLE IF NOT EXISTS benchmark_data (
            sensor_id TEXT,
            timestamp TIMESTAMP,
            value DOUBLE,
            city TEXT,
            PRIMARY KEY (sensor_id, timestamp)
        )
    """)
    
    # Préparer les données
    start_time = time.time()
    data = []
    for i in range(n):
        data.append((
            f"sensor_{i % 1000}",
            start_time + i,
            float(i * 0.1),
            ["Alger", "Oran", "Constantine"][i % 3]
        ))
    
    # Utiliser des UNLOGGED BATCH
    from cassandra.query import BatchStatement, BatchType
    
    start = time.perf_counter()
    
    # Diviser en batches de 100
    batch_size = 100
    query = session.prepare("""
        INSERT INTO benchmark_data (sensor_id, timestamp, value, city)
        VALUES (?, ?, ?, ?)
    """)
    
    for i in range(0, len(data), batch_size):
        batch = BatchStatement(BatchType.UNLOGGED)
        for row in data[i:i + batch_size]:
            batch.add(query, row)
        session.execute(batch)
        
        if (i + batch_size) % 10000 == 0:
            print(f"  Cassandra: {min(i + batch_size, n):,}/{n:,} lignes")
    
    elapsed = time.perf_counter() - start
    throughput = n / elapsed
    
    print(f"\nCassandra Écriture:")
    print(f"  Temps: {elapsed:.2f}s")
    print(f"  Débit: {throughput:.0f} lignes/seconde")
    print(f"  Latence moyenne: {elapsed/n*1000:.2f}ms")
    
    cluster.shutdown()
    return {"throughput_rps": throughput, "avg_latency_ms": elapsed/n*1000}


# ─── Ex2 : Benchmark Lecture ─────────────────────────────────────────────────

def benchmark_read_redis():
    """Point lookup, range (ZRANGE), complex (pipeline multi-get)"""
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    # Préparer les clés de test
    keys = [f"product:{i}" for i in range(1000)]
    
    results = {}
    
    # 1. Point lookup
    def point_lookup():
        for key in keys:
            r.get(key)
    
    results["point_lookup"] = measure_latency(point_lookup, 1000)
    
    # 2. Range query (simulé avec sorted set)
    # Ajouter des scores pour le test
    for i, key in enumerate(keys[:100]):
        r.zadd("test_sorted", {i: key})
    
    def range_query():
        r.zrange("test_sorted", 0, 49)  # Top 50
    
    results["range_query"] = measure_latency(range_query, 100)
    
    # 3. Complex multi-get
    def multi_get():
        pipe = r.pipeline()
        for key in keys[:100]:
            pipe.get(key)
        pipe.execute()
    
    results["multi_get"] = measure_latency(multi_get, 100)
    
    print("\nRedis Lecture:")
    for test_name, stats in results.items():
        print(f"  {test_name}:")
        print(f"    P50: {stats['p50_ms']:.2f}ms")
        print(f"    P95: {stats['p95_ms']:.2f}ms")
        print(f"    P99: {stats['p99_ms']:.2f}ms")
        print(f"    Throughput: {stats['throughput_rps']:.0f} rps")
    
    return results


def benchmark_read_mongodb():
    """find_one, find avec range, aggregate pipeline"""
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    db = client["benchmark"]
    
    results = {}
    
    # 1. Point lookup
    def point_lookup():
        for i in range(1000):
            db.benchmark.find_one({"_id": i})
    
    results["point_lookup"] = measure_latency(point_lookup, 1000)
    
    # 2. Range query
    def range_query():
        db.benchmark.find({
            "timestamp": {"$gte": time.time() - 3600}
        }).limit(100)
        list(cursor)  # Exécuter la requête
    
    results["range_query"] = measure_latency(range_query, 100)
    
    # 3. Aggregate pipeline
    def aggregate_query():
        db.benchmark.aggregate([
            {"$match": {"location.city": "Alger"}},
            {"$group": {
                "_id": "$metadata.type",
                "avg_value": {"$avg": "$value"},
                "count": {"$sum": 1}
            }},
            {"$sort": {"count": -1}}
        ])
        list(cursor)  # Exécuter
    
    results["aggregate"] = measure_latency(aggregate_query, 100)
    
    print("\nMongoDB Lecture:")
    for test_name, stats in results.items():
        print(f"  {test_name}:")
        print(f"    P50: {stats['p50_ms']:.2f}ms")
        print(f"    P95: {stats['p95_ms']:.2f}ms")
        print(f"    P99: {stats['p99_ms']:.2f}ms")
        print(f"    Throughput: {stats['throughput_rps']:.0f} rps")
    
    client.close()
    return results


# ─── Ex3 : Charge concurrente ─────────────────────────────────────────────────

def benchmark_concurrent(db_fn: Callable, n_clients: int = 50, requests_per_client: int = 200):
    """Lancer n_clients threads simultanés"""
    import threading
    import queue
    
    results = queue.Queue()
    
    def worker():
        try:
            stats = db_fn()
            results.put(stats)
        except Exception as e:
            results.put({"error": str(e)})
    
    # Lancer les threads
    start = time.perf_counter()
    threads = []
    
    for i in range(n_clients):
        thread = threading.Thread(target=worker)
        threads.append(thread)
        thread.start()
    
    # Attendre la fin de tous les threads
    for thread in threads:
        thread.join()
    
    elapsed = time.perf_counter() - start
    
    # Collecter les résultats
    all_stats = []
    while not results.empty():
        all_stats.append(results.get())
    
    # Filtrer les erreurs
    valid_stats = [s for s in all_stats if "error" not in s]
    
    if valid_stats:
        avg_p50 = sum(s["p50_ms"] for s in valid_stats) / len(valid_stats)
        avg_p95 = sum(s["p95_ms"] for s in valid_stats) / len(valid_stats)
        avg_throughput = sum(s["throughput_rps"] for s in valid_stats) / len(valid_stats)
        
        print(f"\nCharge Concurrente ({n_clients} clients):")
        print(f"  Temps total: {elapsed:.2f}s")
        print(f"  Requêtes totales: {n_clients * requests_per_client:,}")
        print(f"  P50 moyen: {avg_p50:.2f}ms")
        print(f"  P95 moyen: {avg_p95:.2f}ms")
        print(f"  Débit moyen: {avg_throughput:.0f} rps")
        print(f"  Succès: {len(valid_stats)}/{len(all_stats)} threads")
    
    return {"avg_p50_ms": avg_p50, "avg_p95_ms": avg_p95, "avg_throughput_rps": avg_throughput}


# ─── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("🚀 Benchmark NoSQL - Comparatif des 4 technologies")
    print("="*60)
    
    N = 10_000  # Réduire pour les tests, 100_000 pour la production
    
    print(f"\n📝 Benchmark Écriture ({N:,} enregistrements)")
    benchmark_write_redis(N)
    benchmark_write_mongodb(N)
    benchmark_write_cassandra(N)
    
    print(f"\n📖 Benchmark Lecture (1,000 requêtes)")
    benchmark_read_redis()
    benchmark_read_mongodb()
    
    print(f"\n⚡ Test Charge Concurrente (50 clients)")
    # benchmark_concurrent(...)
    
    print("\n✅ Benchmark terminé ! Consultez RAPPORT.md pour l'analyse.")
