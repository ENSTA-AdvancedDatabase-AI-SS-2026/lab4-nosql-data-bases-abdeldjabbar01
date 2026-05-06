/**
 * TP2 - Exercice 1 : Modélisation de données médicales
 * Création de la structure de la base et insertion de données de test
 */

use("medical_db");

// Schema de validation pour la collection patients
db.createCollection("patients", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "nom", "prenom", "date_naissance", "wilaya", "sexe"],
      properties: {
        _id: { bsonType: "string" },
        nom: { bsonType: "string", minLength: 2 },
        prenom: { bsonType: "string", minLength: 2 },
        date_naissance: { bsonType: "date" },
        wilaya: { bsonType: "string" },
        sexe: { bsonType: "string", enum: ["M", "F"] },
        groupe_sanguin: { bsonType: "string" },
        allergies: { bsonType: "array" },
        consultations: { bsonType: "array" },
        created_at: { bsonType: "date" }
      }
    }
  }
});

// ─── 1.2 : Insérer des patients avec données algériennes ──────────────────────
// TODO: Insérer au moins 20 patients avec :
// - Prénoms et noms algériens variés
// - Wilayas différentes (Alger, Oran, Constantine, Annaba, Blida...)
// - Pathologies courantes (Diabète, HTA, Asthme, etc.)
// Insertion de patients algeriens pour les tests
// On utilise des données réalistes pour le contexte algérien

// Premier groupe : Alger et ses environs
db.patients.insertMany([
  {
    _id: "P001",
    nom: "Bensalah",
    prenom: "Mohamed",
    date_naissance: new Date("1985-03-15"),
    wilaya: "Alger",
    commune: "Bab Ezzouar",
    sexe: "M",
    groupe_sanguin: "O+",
    allergies: ["penicilline", "pollen"],
    telephone: "0555123456",
    created_at: new Date("2024-01-15")
  },
  {
    _id: "P002",
    nom: "Kaci",
    prenom: "Fatima",
    date_naissance: new Date("1990-07-22"),
    wilaya: "Alger",
    commune: "Hydra",
    sexe: "F",
    groupe_sanguin: "A+",
    allergies: [],
    telephone: "0556789012",
    created_at: new Date("2024-01-16")
  },
  {
    _id: "P003",
    nom: "Bensalem",
    prenom: "Ahmed",
    date_naissance: new Date("1980-01-01"),
    wilaya: "Alger",
    commune: "Bab Ezzouar",
    sexe: "M",
    groupe_sanguin: "O+",
    allergies: ["Pénicilline"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-15"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Hypertension artérielle",
        tension: { systolique: 145, diastolique: 92 },
        medicaments: [
          { nom: "Amlodipine", dosage: "5mg", duree: "30 jours" }
        ],
        notes: "Surveillance tensionnelle recommandée"
      },
      {
        id: UUID(),
        date: new Date("2024-03-20"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Diabète déséquilibré",
        tension: { systolique: 150, diastolique: 95 },
        medicaments: [
          { nom: "Metformine", dosage: "850mg", duree: "90 jours" },
          { nom: "Amlodipine", dosage: "10mg", duree: "30 jours" }
        ],
        notes: "Ajustement traitement en cours"
      }
    ]
  },
  {
    cin: "198502034567",
    nom: "Kaci",
    prenom: "Fatima",
    dateNaissance: new Date("1985-02-03"),
    sexe: "F",
    adresse: { wilaya: "Oran", commune: "Es Senia" },
    groupeSanguin: "A+",
    antecedents: ["Asthme"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-10"),
        medecin: { nom: "Dr. Benali", specialite: "Pneumologie" },
        diagnostic: "Crise d'asthme",
        medicaments: [
          { nom: "Ventoline", dosage: "100ug", duree: "15 jours" },
          { nom: "Seretide", dosage: "250/50", duree: "30 jours" }
        ],
        notes: "Éviter allergènes"
      }
    ]
  },
  {
    cin: "199004056789",
    nom: "Cherif",
    prenom: "Mohamed",
    dateNaissance: new Date("1990-04-05"),
    sexe: "M",
    adresse: { wilaya: "Constantine", commune: "El Khroub" },
    groupeSanguin: "B+",
    antecedents: [],
    allergies: ["Amoxicilline"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-25"),
        medecin: { nom: "Dr. Zerrouki", specialite: "Médecine générale" },
        diagnostic: "Gastro-entérite",
        medicaments: [
          { nom: "Smecta", dosage: "3g/jour", duree: "3 jours" },
          { nom: "Flagyl", dosage: "500mg", duree: "7 jours" }
        ],
        notes: "Hydratation abondante"
      },
      {
        id: UUID(),
        date: new Date("2024-03-15"),
        medecin: { nom: "Dr. Zerrouki", specialite: "Médecine générale" },
        diagnostic: "Rhinite allergique",
        medicaments: [
          { nom: "Zyrtec", dosage: "10mg", duree: "30 jours" }
        ],
        notes: "Test allergologie recommandé"
      }
    ]
  },
  {
    cin: "197806078901",
    nom: "Boudiaf",
    prenom: "Samira",
    dateNaissance: new Date("1978-06-07"),
    sexe: "F",
    adresse: { wilaya: "Annaba", commune: "El Bouni" },
    groupeSanguin: "AB+",
    antecedents: ["Hypothyroïdie"],
    allergies: ["Iode"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-20"),
        medecin: { nom: "Dr. Hadj", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie",
        medicaments: [
          { nom: "Levothyrox", dosage: "75ug", duree: "90 jours" }
        ],
        notes: "Contrôle TSH dans 3 mois"
      }
    ]
  },
  {
    cin: "199208091234",
    nom: "Haddad",
    prenom: "Yacine",
    dateNaissance: new Date("1992-08-09"),
    sexe: "M",
    adresse: { wilaya: "Blida", commune: "Blida" },
    groupeSanguin: "O-",
    antecedents: ["Migraine"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-03-01"),
        medecin: { nom: "Dr. Kaci", specialite: "Neurologie" },
        diagnostic: "Migraine avec aura",
        medicaments: [
          { nom: "Imitrex", dosage: "100mg", duree: "15 jours" },
          { nom: "Propranolol", dosage: "40mg", duree: "30 jours" }
        ],
        notes: "Journal des crises recommandé"
      }
    ]
  }
];

db.patients.insertMany(patients);

// ─── 1.3 : Collection analyses (référencée) ───────────────────────────────────
// TODO: Créer des analyses pour les patients insérés
// Types : "Glycémie", "NFS", "Lipidogramme", "Créatinine", "ECG"

const analyses = [
  {
    patient_id: db.patients.findOne({"_id": "P001"})._id,
    date: new Date("2024-01-20"),
    type: "Glycémie",
    resultats: { 
      glycemie_ajeun: 1.45,
      glycemie_postprandiale: 2.10,
      hba1c: 8.2
    },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: db.patients.findOne({"_id": "P001"})._id,
    date: new Date("2024-03-25"),
    type: "NFS",
    resultats: {
      hemoglobine: 14.2,
      globules_rouges: 4.8,
      globules_blancs: 7.2,
      plaquettes: 280
    },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: db.patients.findOne({"_id": "P004"})._id,
    date: new Date("2024-02-15"),
    type: "ECG",
    resultats: {
      rythme: "Sinusal",
      frequence: 78,
      "pr": 0.16,
      "qrs": 0.08,
      "qt": 0.40,
      interpretation: "Normal"
    },
    laboratoire: "Cardio Oran",
    valide: true
  },
  {
    patient_id: db.patients.findOne({cin: "199004056789"})._id,
    date: new Date("2024-01-28"),
    type: "Lipidogramme",
    resultats: {
      cholesterol_total: 2.10,
      ldl: 1.30,
      hdl: 0.55,
      triglycerides: 1.25
    },
    laboratoire: "BioLab Constantine",
    valide: true
  },
  {
    patient_id: db.patients.findOne({cin: "197806078901"})._id,
    date: new Date("2024-02-25"),
    type: "Créatinine",
    resultats: {
      creatinine: 85,
      clearance_creatinine: 75,
      uree: 5.2
    },
    laboratoire: "Labo Annaba",
    valide: true
  }
];

db.analyses.insertMany(analyses);

print("✅ Modélisation terminée. Patients insérés:", db.patients.countDocuments());
print("✅ Analyses insérées:", db.analyses.countDocuments());
