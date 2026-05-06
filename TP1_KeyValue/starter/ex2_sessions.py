/*
TP1 - Exercice 2 : Gestion des sessions utilisateurs
Implementation de sessions avec expiration glissante
*/
import redis
import json
import time
import uuid
from typing import Optional, Dict

r = redis.Redis(host='localhost', port=6379, decode_responses=True)

SESSION_TTL = 1800  # 30 minutes en secondes


def create_user_session(r, user_id, user_data, ttl_seconds=3600):
    """
    Crée une nouvelle session utilisateur
    """
    session_key = f"session:{user_id}"
    
    # Stocker les donnees de session
    for key, value in user_data.items():
        r.hset(session_key, key, str(value))
    
    # Configurer l'expiration
    r.expire(session_key, ttl_seconds)
    
    # Ajouter a la liste des sessions actives
    r.sadd("active_sessions", user_id)
    
    return session_key


def renew_session(r, user_id):
    """
    Renouveler manuellement une session (TTL)
    """
    session_key = f"session:{user_id}"
    return r.expire(session_key, SESSION_TTL) == 1


def get_session(r, user_id):
    """
    Récupérer une session et renouveler son TTL (sliding expiration)
    """
    session_key = f"session:{user_id}"
    session_data = r.hgetall(session_key)
    
    if not session_data:
        return None
    
    # Mettre à jour last_access et TTL (sliding expiration)
    session_data["last_access"] = int(time.time())
    for key, value in session_data.items():
        r.hset(session_key, key, str(value))
    
    return session_data


def destroy_session(r, user_id):
    """
    Supprimer une session (logout)
    """
    session_key = f"session:{user_id}"
    
    # Retirer de l'ensemble des sessions utilisateur
    r.srem("active_sessions", user_id)
    
    # Supprimer la session
    return r.delete(session_key) > 0


def get_user_sessions(r):
    """
    Lister toutes les sessions actives
    """
    return list(r.smembers("active_sessions"))


def cleanup_expired_sessions(r):
    """
    Nettoyer les sessions expirées
    Retourner le nombre de sessions supprimées
    """
    session_ids = get_user_sessions(r)
    cleaned = 0
    
    for session_id in session_ids:
        if not get_session(r, session_id):  # get_session supprime automatiquement les expirées
            cleaned += 1
    
    return cleaned


# Exemple d'utilisation
if __name__ == "__main__":
    r = redis.Redis(host='localhost', port=6379)
    
    # Nettoyer les anciennes sessions
    cleanup_expired_sessions(r)
    
    # Creer une session pour utilisateur
    user_id = "user_123"
    session_data = {
        "username": "ahmed",
        "email": "ahmed@example.com",
        "role": "student",
        "login_time": time.time()
    }
    
    session_key = create_user_session(r, user_id, session_data)
    print(f"Session cree: {session_key}")
    
    # Renouveler la session
    renew_session(r, user_id)
    
    # Verifier la session
    session_info = get_session(r, user_id)
    print(f"Info session: {session_info}")
    session_id2 = create_user_session(r, "user:42", user_data)
    sessions = get_user_sessions(r)
    print(f"Sessions actives: {len(sessions)}")
    
    # Détruire une session
    destroy_session(r, "user:42")
    sessions_after = get_user_sessions(r)
    print(f"Sessions après logout: {len(sessions_after)}")
