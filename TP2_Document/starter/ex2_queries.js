/**
 * TP2 - Exercice 2 : Requetes de base
 * Requetes simples sur la collection patients filtrage dans les dossiers médicaux
 */

use("medical_db");

// ─── 2.1 : Patients diabétiques de plus de 50 ans à Alger ─────────────────────
print("=== 2.1 : Patients diabétiques >50 ans à Alger ===");

const patientsDiabetiquesAlger = db.patients.find({
  "consultations.diagnostic": /diabete/i,
  "date_naissance": { $lt: new Date("1974-01-01") },
  "wilaya": "Alger"
}).toArray();

print(`Trouvé: ${patientsDiabetiquesAlger.length} patients`);
printjson(patientsDiabetiquesAlger.map(p => ({
  nom: p.nom,
  prenom: p.prenom,
  age: Math.floor((new Date() - p.dateNaissance) / (365.25 * 24 * 60 * 60 * 1000)),
  wilaya: p.adresse.wilaya
})));

// ─── 2.2 : Patients allergiques à la Pénicilline avec ≥3 consultations ───────
print("\n=== 2.2 : Patients allergiques Pénicilline avec ≥3 consultations ===");

const patientsPenicilline = db.patients.find({
  allergies: "Pénicilline",
  consultations: { $exists: true, $not: { $size: 0 } }
}).toArray();

const patientsPenicilline3Plus = patientsPenicilline.filter(p => p.consultations.length >= 3);

print(`Trouvé: ${patientsPenicilline3Plus.length} patients`);
printjson(patientsPenicilline3Plus.map(p => ({
  nom: p.nom,
  prenom: p.prenom,
  consultationsCount: p.consultations.length,
  allergies: p.allergies
})));

// ─── 2.3 : Projection : Nom, prénom, dernière consultation seulement ────────
print("\n=== 2.3 : Projection avec dernière consultation ===");

const patientsProjection = db.patients.find({}, {
  nom: 1,
  prenom: 1,
  "consultations": { $slice: -1 }  // Dernière consultation seulement
}).toArray();

print("Projection (5 premiers patients):");
printjson(patientsProjection.slice(0, 5).map(p => ({
  nom: p.nom,
  prenom: p.prenom,
  derniereConsultation: p.consultations[0] ? {
    date: p.consultations[0].date,
    diagnostic: p.consultations[0].diagnostic,
    medecin: p.consultations[0].medecin.nom
  } : null
})));

// ─── 2.4 : Patients sans antécédents avec tension systolique >140 ───────────
print("\n=== 2.4 : Patients sans antécédents, tension >140 ===");

const patientsTensionElevee = db.patients.find({
  antecedents: { $size: 0 },
  "consultations.tension.systolique": { $gt: 140 }
}).toArray();

print(`Trouvé: ${patientsTensionElevee.length} patients`);
printjson(patientsTensionElevee.map(p => {
  const derniereConsultation = p.consultations[p.consultations.length - 1];
  return {
    nom: p.nom,
    prenom: p.prenom,
    tension: derniereConsultation?.tension,
    diagnostic: derniereConsultation?.diagnostic
  };
}));

// ─── 2.5 : Recherche textuelle sur les diagnostics ─────────────────────────────
print("\n=== 2.5 : Recherche textuelle sur diagnostics ===");

// Créer d'abord un index text
try {
  db.patients.createIndex({ "consultations.diagnostic": "text" });
  print("✅ Index textuel créé");
} catch (e) {
  print("ℹ️  Index textuel déjà existant");
}

// Rechercher les termes "hypertension" ou "diabète"
const rechercheTextuelle = db.patients.find({
  $text: { $search: "hypertension diabète" }
}, {
  score: { $meta: "textScore" }
}).sort({
  score: { $meta: "textScore" }
}).toArray();

print(`Recherche textuelle - Trouvé: ${rechercheTextuelle.length} patients`);
printjson(rechercheTextuelle.slice(0, 3).map(p => ({
  nom: p.nom,
  prenom: p.prenom,
  score: p.score,
  diagnosticsTrouves: p.consultations.map(c => c.diagnostic).filter(d => 
    d.toLowerCase().includes("hypertension") || d.toLowerCase().includes("diabète")
  )
})));

// ─── Requêtes additionnelles pour démonstration ──────────────────────────────────

// Patients par groupe sanguin
print("\n=== Répartition par groupe sanguin ===");
const groupesSanguins = db.patients.aggregate([
  { $group: { _id: "$groupeSanguin", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
]).toArray();
printjson(groupesSanguins);

// Patients avec le plus de consultations
print("\n=== Patients avec le plus de consultations ===");
const patientsPlusConsultations = db.patients.find({
  consultations: { $exists: true }
}).toArray()
.sort((a, b) => b.consultations.length - a.consultations.length)
.slice(0, 5);

printjson(patientsPlusConsultations.map(p => ({
  nom: p.nom,
  prenom: p.prenom,
  consultationsCount: p.consultations.length
})));

print("\n✅ Requêtes de base terminées");
