/**
 * TP2 - Exercice 5 : $lookup et Données Référencées
 * Use Case : Jointure patients et analyses médicales
 */

use("medical_db");

// ─── 5.1 : Joindre patients et analyses pour le dossier complet ─────────────
print("=== 5.1 : Dossier complet patient avec analyses ===");

const dossierComplet = db.patients.aggregate([
  {
    $lookup: {
      from: "analyses",
      localField: "_id",
      foreignField: "patient_id",
      as: "analysesComplete"
    }
  },
  { $limit: 3 }  // Limiter pour la démonstration
]).toArray();

print("Dossiers complets (3 premiers patients):");
printjson(dossierComplet.map(p => ({
  cin: p.cin,
  nom: p.nom,
  prenom: p.prenom,
  consultationsCount: p.consultations.length,
  analysesCount: p.analysesComplete.length,
  dernieresAnalyses: p.analysesComplete.slice(-2).map(a => ({
    type: a.type,
    date: a.date,
    valide: a.valide
  }))
})));

// ─── 5.2 : Patients avec glycémie dépassant 1.26 g/L ───────────────────────
print("\n=== 5.2 : Patients avec glycémie > 1.26 g/L ===");

const patientsGlycemieElevee = db.analyses.aggregate([
  {
    $match: {
      type: "Glycémie",
      "resultats.glycemie_ajeun": { $gt: 1.26 }
    }
  },
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patientInfo"
    }
  },
  { $unwind: "$patientInfo" },
  {
    $project: {
      cin: "$patientInfo.cin",
      nom: "$patientInfo.nom",
      prenom: "$patientInfo.prenom",
      wilaya: "$patientInfo.adresse.wilaya",
      glycemie_ajeun: "$resultats.glycemie_ajeun",
      glycemie_postprandiale: "$resultats.glycemie_postprandiale",
      hba1c: "$resultats.hba1c",
      dateAnalyse: "$date",
      laboratoire: "$laboratoire"
    }
  },
  { $sort: { "resultats.glycemie_ajeun": -1 } }
]).toArray();

print(`Trouvé: ${patientsGlycemieElevee.length} patients avec glycémie élevée`);
printjson(patientsGlycemieElevee);

// ─── 5.3 : Statistiques croisées : taux d'analyses anormales par wilaya ───────
print("\n=== 5.3 : Taux d'analyses anormales par wilaya ===");

// Définir les seuils normaux pour chaque type d'analyse
const seuilsNormaux = {
  "Glycémie": { glycemie_ajeun: { min: 0.70, max: 1.10 } },
  "NFS": { 
    hemoglobine: { min: 12.0, max: 16.0 },
    globules_blancs: { min: 4.0, max: 10.0 }
  },
  "Lipidogramme": { 
    cholesterol_total: { min: 1.50, max: 2.50 },
    ldl: { min: 0.0, max: 1.60 }
  },
  "Créatinine": { creatinine: { min: 60, max: 110 } }
};

const statistiquesAnormales = db.analyses.aggregate([
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patientInfo"
    }
  },
  { $unwind: "$patientInfo" },
  {
    $addFields: {
      wilaya: "$patientInfo.adresse.wilaya",
      estAnormale: {
        $switch: {
          branches: [
            {
              case: { $eq: ["$type", "Glycémie"] },
              then: { 
                $or: [
                  { $lt: ["$resultats.glycemie_ajeun", 0.70] },
                  { $gt: ["$resultats.glycemie_ajeun", 1.10] }
                ]
              }
            },
            {
              case: { $eq: ["$type", "NFS"] },
              then: { 
                $or: [
                  { $lt: ["$resultats.hemoglobine", 12.0] },
                  { $gt: ["$resultats.hemoglobine", 16.0] },
                  { $lt: ["$resultats.globules_blancs", 4.0] },
                  { $gt: ["$resultats.globules_blancs", 10.0] }
                ]
              }
            },
            {
              case: { $eq: ["$type", "Lipidogramme"] },
              then: { 
                $or: [
                  { $lt: ["$resultats.cholesterol_total", 1.50] },
                  { $gt: ["$resultats.cholesterol_total", 2.50] }
                ]
              }
            },
            {
              case: { $eq: ["$type", "Créatinine"] },
              then: { 
                $or: [
                  { $lt: ["$resultats.creatinine", 60] },
                  { $gt: ["$resultats.creatinine", 110] }
                ]
              }
            }
          ],
          default: false
        }
      }
    }
  },
  {
    $group: {
      _id: "$wilaya",
      totalAnalyses: { $sum: 1 },
      analysesAnormales: { $sum: { $cond: ["$estAnormale", 1, 0] } },
      typesAnalyses: { $addToSet: "$type" }
    }
  },
  {
    $addFields: {
      tauxAnormalite: {
        $round: [
          { $multiply: [
            { $divide: ["$analysesAnormales", "$totalAnalyses"] },
            100
          ]},
          2
        ]
      }
    }
  },
  { $sort: { tauxAnormalite: -1 } }
]).toArray();

print("Taux d'analyses anormales par wilaya:");
printjson(statistiquesAnormales);

// ─── Analyses additionnelles avec $lookup ──────────────────────────────────

// Patients avec analyses et consultations récentes
print("\n=== Analyses complémentaires ===");

const analysesRecentes = db.patients.aggregate([
  { $unwind: "$consultations" },
  {
    $match: {
      "consultations.date": {
        $gte: new Date(new Date().setMonth(new Date().getMonth() - 3)) // 3 derniers mois
      }
    }
  },
  {
    $lookup: {
      from: "analyses",
      localField: "_id",
      foreignField: "patient_id",
      as: "analysesRecentes"
    }
  },
  {
    $addFields: {
      analysesRecentesCount: {
        $size: {
          $filter: {
            input: "$analysesRecentes",
            cond: {
              $gte: ["$$this.date", new Date(new Date().setMonth(new Date().getMonth() - 3))]
            }
          }
        }
      }
    }
  },
  {
    $project: {
      cin: 1,
      nom: 1,
      prenom: 1,
      "consultations.date": 1,
      "consultations.diagnostic": 1,
      analysesRecentesCount: 1,
      dernieresAnalyses: {
        $slice: [
          { $sortArray: { input: "$analysesRecentes", sortBy: { date: -1 } } },
          2
        ]
      }
    }
  },
  { $limit: 5 }
]).toArray();

print("Patients avec consultations et analyses récentes:");
printjson(analysesRecentes);

// Résumé des jointures
print("\n=== Résumé des jointures $lookup ===");
print(`Total patients: ${db.patients.countDocuments()}`);
print(`Total analyses: ${db.analyses.countDocuments()}`);
print(`Patients avec analyses: ${dossierComplet.filter(p => p.analysesComplete.length > 0).length}`);
print(`Analyses anormales: ${statistiquesAnormales.reduce((sum, s) => sum + s.analysesAnormales, 0)}`);

print("\n✅ Exercices $lookup terminés");
