/**
 * TP2 - Exercice 4 : Index et Optimisation
 */

use("medical_db");

// ─── 4.1 : Créer les index appropriés ────────────────────────────────────────

// Index 1 : Recherche fréquente par wilaya + antécédents
db.patients.createIndex({ "adresse.wilaya": 1, antecedents: 1 });
print("✅ Index composé wilaya+antécédents créé");

// Index 2 : Recherche par date de consultation
db.patients.createIndex({ "consultations.date": -1 });
print("✅ Index sur dates de consultations créé");

// Index 3 : Texte sur diagnostics pour recherche full-text
db.patients.createIndex({ "consultations.diagnostic": "text" });
print("✅ Index textuel sur diagnostics créé");

// Index 4 : Analyses par patient (lookup)
db.analyses.createIndex({ patient_id: 1, date: -1 });
print("✅ Index composé patient+date sur analyses créé");


// ─── 4.2 : Comparer avec explain() ────────────────────────────────────────────

// Requête de test
const requeteTest = {
  "adresse.wilaya": "Alger",
  antecedents: "Diabète type 2"
};

print("=== AVANT index ===");
const explainAvant = db.patients.find(requeteTest).explain("executionStats");
print(`Documents examinés: ${explainAvant.executionStats.totalDocsExamined}`);
print(`Documents retournés: ${explainAvant.executionStats.totalDocsExamined}`);
print(`Temps exécution: ${explainAvant.executionStats.executionTimeMillis}ms`);

print("\n=== APRÈS index ===");
const explainApres = db.patients.find(requeteTest).explain("executionStats");
print(`Documents examinés: ${explainApres.executionStats.totalDocsExamined}`);
print(`Documents retournés: ${explainApres.executionStats.totalDocsExamined}`);
print(`Temps exécution: ${explainApres.executionStats.executionTimeMillis}ms`);

const amelioration = explainAvant.executionStats.totalDocsExamined / explainApres.executionStats.totalDocsExamined;
print(`Amélioration: ${amelioration.toFixed(1)}x moins de documents scannés`);

// ─── 4.4 : Index TTL pour archivage ───────────────────────────────────────────
// Index TTL pour archivage automatique après 5 ans
db.analyses.createIndex(
  { date: 1 },
  { expireAfterSeconds: 5 * 365 * 24 * 60 * 60 } // 5 ans en secondes
);
print("✅ Index TTL créé sur analyses (5 ans)");
