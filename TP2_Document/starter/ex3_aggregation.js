/*
TP2 - Exercice 3 : Aggregation
Operations d'aggregation sur les donnees medicales
*/

use("medical_db");

// ─── 3.1// 1. Distribution des diagnostics par wilaya
print("=== Distribution des diagnostics par wilaya ===");

const diagParWilaya = db.patients.aggregate([
  { $unwind: "$consultations" },
  { $group: {
      _id: { 
        wilaya: "$adresse.wilaya", 
        diagnostic: "$consultations.diagnostic" 
      },
      count: { $sum: 1 }
    }
  },
  { $sort: { count: -1 } },
  { $limit: 20 }
]).toArray();

// printjson(diagParWilaya);

// ─── 3.2 : Médicament le plus prescrit par spécialité ─────────────────────────
print("\n=== 3.2 : Top médicaments par spécialité ===");

const medsParSpecialite = db.patients.aggregate([
  { $unwind: "$consultations" },
  { $unwind: "$consultations.medicaments" },
  { $group: {
      _id: { 
        specialite: "$consultations.medecin.specialite",
        medicament: "$consultations.medicaments.nom"
      },
      count: { $sum: 1 }
    }
  },
  { $sort: { "_id.specialite": 1, count: -1 } },
  { $group: {
      _id: "$_id.specialite",
      topMedicament: { $first: "$_id.medicament" },
      prescriptions: { $first: "$count" }
    }
  },
  { $sort: { prescriptions: -1 } }
]).toArray();

// ─── 3.3 : Évolution mensuelle des consultations ──────────────────────────────
print("\n=== 3.3 : Consultations par mois (12 derniers mois) ===");

const evolutionMensuelle = db.patients.aggregate([
  { $unwind: "$consultations" },
  { $match: {
    "consultations.date": {
      $gte: new Date(new Date().setFullYear(new Date().getFullYear() - 1))
    }
  }},
  { $group: {
      _id: {
        year: { $year: "$consultations.date" },
        month: { $month: "$consultations.date" }
      },
      count: { $sum: 1 },
      firstDate: { $min: "$consultations.date" }
    }
  },
  { $sort: { "_id.year": 1, "_id.month": 1 } },
  { $project: {
      _id: 0,
      month: {
        $concat: [
          { $toString: "$_id.year" },
          "-",
          { $cond: {
            if: { $lt: ["$_id.month", 10] },
            then: { $concat: ["0", { $toString: "$_id.month" }] },
            else: { $toString: "$_id.month" }
          }}
        ]
      },
      consultations: "$count",
      date: "$firstDate"
    }
  }
]).toArray();

// ─── 3.4 : Patients à risque multiple ────────────────────────────────────────
print("\n=== 3.4 : Profil patients à risque élevé ===");

const patientsRisque = db.patients.aggregate([
  {
    $match: {
      antecedents: { $all: ["Diabète type 2", "HTA"] },
      dateNaissance: { $lte: new Date(new Date().setFullYear(new Date().getFullYear() - 60)) }
    }
  },
  { $addFields: {
      age: {
        $divide: [
          { $subtract: [new Date(), "$dateNaissance"] },
          365.25 * 24 * 60 * 60 * 1000
        ]
      },
      consultationCount: { $size: "$consultations" }
    }
  },
  { $group: {
      _id: null,
      totalPatients: { $sum: 1 },
      avgAge: { $avg: "$age" },
      avgConsultations: { $avg: "$consultationCount" },
      maxConsultations: { $max: "$consultationCount" },
      minConsultations: { $min: "$consultationCount" }
    }
  },
  { $project: {
      _id: 0,
      groupe: "Patients à risque (Diabète + HTA + >60 ans)",
      nombrePatients: "$totalPatients",
      ageMoyen: { $round: ["$avgAge", 1] },
      consultationsMoyennes: { $round: ["$avgConsultations", 1] },
      consultationsMax: "$maxConsultations",
      consultationsMin: "$minConsultations"
    }
  }
]).toArray();

// ─── 3.5 : Rapport médecins ───────────────────────────────────────────────────
print("\n=== 3.5 : Top 5 médecins & taux de ré-consultation ===");

const rapportMedecins = db.patients.aggregate([
  { $unwind: "$consultations" },
  { $group: {
      _id: "$consultations.medecin.nom",
      specialite: { $first: "$consultations.medecin.specialite" },
      totalConsultations: { $sum: 1 },
      uniquePatients: { $addToSet: "$cin" }
    }
  },
  { $addFields: {
      patientCount: { $size: "$uniquePatients" },
      tauxReconsultation: {
        $round: [
          {
            $multiply: [
              { $divide: [
                { $subtract: ["$totalConsultations", "$patientCount"] },
                "$patientCount"
              ]},
              100
            ]
          },
          2
        ]
      }
    }
  },
  { $project: {
      _id: 0,
      medecin: "$_id",
      specialite: "$specialite",
      totalConsultations: "$totalConsultations",
      patientsUniques: "$patientCount",
      tauxReconsultation: "$tauxReconsultation"
    }
  },
  { $sort: { totalConsultations: -1 } },
  { $limit: 5 }
]).toArray();

printjson(rapportMedecins);
