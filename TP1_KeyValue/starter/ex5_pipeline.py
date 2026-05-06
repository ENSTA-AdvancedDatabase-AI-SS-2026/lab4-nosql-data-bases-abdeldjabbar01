"""
TP1 - Exercice 5 : Pipeline & Transactions Redis
Use Case : Commande atomique et insertion en masse
"""
import redis
import json
import time
from typing import List, Dict

r = redis.Redis(host='localhost', port=6379, decode_responses=True)


def bulk_insert_products(r, products: List[Dict]) -> int:
    """
    Insérer plusieurs produits en utilisant un pipeline
    Retourner le nombre de produits insérés
    """
    pipe = r.pipeline()
    
    for product in products:
        product_id = product["id"]
        key = f"product:{product_id}"
        
        # Ajouter au pipeline
        for field, value in product.items():
            if field != "id":  # Ne pas stocker l'ID dans le hash
                pipe.hset(key, field, str(value))
    
    # Exécuter tout d'un coup
    results = pipe.execute()
    
    # Compter les succès (chaque HSET retourne 1 si nouveau, 0 si mise à jour)
    return sum(1 for result in results if result in (0, 1))


def create_order_atomically(r, order_id: str, user_id: str, items: List[Dict]) -> bool:
    """
    Créer une commande de manière atomique avec MULTI/EXEC
    Structure:
    - order:{order_id} (Hash) -> infos commande
    - order_items:{order_id} (Hash) -> produits commandés
    - user_orders:{user_id} (List) -> historique commandes
    - Décrémenter stocks
    """
    try:
        # Démarrer la transaction
        pipe = r.pipeline()
        
        # Créer la commande
        order_key = f"order:{order_id}"
        order_data = {
            "id": order_id,
            "user_id": user_id,
            "created_at": int(time.time()),
            "status": "pending",
            "total_items": str(len(items))
        }
        
        pipe.hmset(order_key, order_data)
        
        # Ajouter les items de commande
        order_items_key = f"order_items:{order_id}"
        for i, item in enumerate(items):
            pipe.hset(order_items_key, str(i), json.dumps(item))
            
            # Décrémenter le stock
            product_key = f"product:{item['product_id']}"
            pipe.hincrby(product_key, "stock", -item["quantity"])
        
        # Ajouter à l'historique de l'utilisateur
        pipe.lpush(f"user_orders:{user_id}", order_id)
        pipe.ltrim(f"user_orders:{user_id}", 0, 49)  # Garder 50 dernières commandes
        
        # Exécuter la transaction atomiquement
        results = pipe.execute()
        
        # Vérifier que toutes les opérations ont réussi
        return all(result is not None for result in results)
        
    except Exception as e:
        print(f"Erreur lors de la création de la commande: {e}")
        return False


def get_order(r, order_id: str) -> Dict:
    """
    Récupérer une commande complète avec ses items
    """
    order_key = f"order:{order_id}"
    order_items_key = f"order_items:{order_id}"
    
    # Récupérer en parallèle avec pipeline
    pipe = r.pipeline()
    pipe.hgetall(order_key)
    pipe.hgetall(order_items_key)
    order_data, items_data = pipe.execute()
    
    if not order_data:
        return None
    
    # Parser les items
    items = []
    for item_json in items_data.values():
        items.append(json.loads(item_json))
    
    return {
        "order": order_data,
        "items": items
    }


def get_user_orders(r, user_id: str, limit: int = 10) -> List[Dict]:
    """
    Récupérer les dernières commandes d'un utilisateur
    """
    order_ids = r.lrange(f"user_orders:{user_id}", 0, limit - 1)
    
    if not order_ids:
        return []
    
    # Récupérer toutes les commandes en parallèle
    pipe = r.pipeline()
    for order_id in order_ids:
        pipe.hgetall(f"order:{order_id}")
    
    orders = pipe.execute()
    
    return [order for order in orders if order]


def benchmark_bulk_insert(r, n_products: int = 1000) -> Dict:
    """
    Comparer les performances: insertion normale vs pipeline
    """
    # Générer des produits de test
    products = []
    for i in range(n_products):
        products.append({
            "id": f"test_{i}",
            "name": f"Produit Test {i}",
            "price": str(100 + i),
            "category": "test",
            "stock": str(10 + i % 100)
        })
    
    # Test insertion normale
    r.flushdb()
    start = time.time()
    
    for product in products:
        key = f"product:{product['id']}"
        for field, value in product.items():
            if field != "id":
                r.hset(key, field, value)
    
    normal_time = time.time() - start
    
    # Test insertion avec pipeline
    r.flushdb()
    start = time.time()
    
    bulk_insert_products(r, products)
    
    pipeline_time = time.time() - start
    
    return {
        "normal_time": normal_time,
        "pipeline_time": pipeline_time,
        "speedup": normal_time / pipeline_time,
        "products_count": n_products
    }


if __name__ == "__main__":
    r.flushdb()
    
    print("=== Test Pipeline & Transactions ===")
    
    # Test bulk insert
    print("\n1. Test insertion en masse:")
    test_products = [
        {"id": "p1", "name": "Smartphone", "price": "50000", "category": "electronics", "stock": "20"},
        {"id": "p2", "name": "Laptop", "price": "80000", "category": "electronics", "stock": "15"},
        {"id": "p3", "name": "Headphones", "price": "5000", "category": "audio", "stock": "50"}
    ]
    
    inserted = bulk_insert_products(r, test_products)
    print(f"Produits insérés: {inserted}")
    
    # Test commande atomique
    print("\n2. Test commande atomique:")
    # D'abord créer quelques produits avec stock
    store_product(r, "p10", {"name": "Test Product", "price": "10000", "category": "test", "stock": "10"})
    
    order_items = [
        {"product_id": "p10", "quantity": 2, "price": "10000"},
        {"product_id": "p1", "quantity": 1, "price": "50000"}
    ]
    
    success = create_order_atomically(r, "order_001", "user_42", order_items)
    print(f"Commande créée: {success}")
    
    # Vérifier le stock
    stock = r.hget("product:p10", "stock")
    print(f"Stock restant p10: {stock}")
    
    # Récupérer la commande
    order = get_order(r, "order_001")
    if order:
        print(f"Commande récupérée: {len(order['items'])} items")
    
    # Benchmark
    print("\n3. Benchmark performance:")
    results = benchmark_bulk_insert(r, 100)
    print(f"Insertion normale: {results['normal_time']:.3f}s")
    print(f"Insertion pipeline: {results['pipeline_time']:.3f}s")
    print(f"Accélération: {results['speedup']:.1f}x")


def store_product(r, product_id, product_data):
    """Helper pour stocker un produit"""
    key = f"product:{product_id}"
    for field, value in product_data.items():
        r.hset(key, field, str(value))
