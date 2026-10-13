# Suivi Scolaire — متابعة التلاميذ

## État du projet

**Phase 5 en cours** : gestion des établissements, élèves, emploi du temps, présences, observations de comportement, évaluations, saisie des notes et moyennes pondérées par matière.

### Fonctionnalités présentes dans cette version

- Base SQLite locale et fonctionnement hors ligne, sans compte ni serveur.
- Interface arabe/français avec préférence enregistrée.
- Création, modification et archivage/restauration d’un établissement.
- Association d’années scolaires à un établissement et activation d’une seule année active par établissement.
- Création et archivage/restauration des classes par établissement et année scolaire.
- Création d’un élève et de son inscription dans une classe au sein d’une transaction SQLite.
- Recherche d’élèves par nom ou matricule et clôture d’une inscription sans supprimer l’historique.
- Conservation des noms originaux; les noms similaires ne sont jamais fusionnés automatiquement.
- Règles de cohérence principales imposées par SQLite (historique, intégrité référentielle, inscriptions actives).
- Gestion des matières bilingues arabe/français.
- Création de créneaux hebdomadaires par classe, avec contrôle des heures et refus des chevauchements.
- Création de séances datées depuis un créneau, suivi du statut (prévue, effectuée, annulée, rattrapage), du sujet traité et des horaires réels.
- Saisie et modification de la présence, de l’absence, du retard et d’autres statuts; un enregistrement est mis à jour plutôt que dupliqué.
- Les séances annulées ne peuvent pas recevoir de nouvelles présences; l’historique des séances et des inscriptions reste conservé.
- Journal des observations comportementales par élève, avec catégorie positive/négative, date, niveau d’importance, description, action et notes du professeur.
- Création d’évaluations par classe et matière, avec type, date, note maximale, coefficient et période facultative.
- Saisie/modification des résultats par élève; les notes nulles sont distinctes d’une absence ou d’une note en attente.
- L’historique des changements de notes est conservé par le déclencheur SQLite existant.
- Calcul d’une moyenne pondérée par matière, normalisée sur 20; seules les évaluations notées contribuent actuellement au calcul. Les résultats en attente, absences et dispenses sont exclus.
- Le module « Suivi » est accessible depuis « Plus » afin de conserver une navigation mobile à cinq destinations.

### Fonctionnalités restant à développer

- Import des listes Excel/CSV avec sélection de feuille, association des colonnes et aperçu avant validation.
- Modification détaillée d’un élève, transfert de classe/établissement et consultation de l’historique complet depuis l’interface.
- Personnalisation de la durée du retard depuis l’interface (la saisie actuelle applique 5 minutes par défaut).
- Configuration avancée des règles de calcul par année/programme/niveau, périodes et politiques d’absence; bulletins et moyennes générales.
- Export XLSX/CSV/PDF, sauvegarde/restauration et rapports.
- Tests sur appareil Android et validation de l’APK signé.

## Vérifications effectuées dans l’environnement de travail

- `python3 tools/test_schema.py` : **24/24 tests de schéma SQLite réussis**.
- Vérification statique des chaînes : **166 clés utilisées, aucune clé manquante et 176 entrées bilingues arabe/français** (`python3 tools/check_localization.py`).

**Non vérifié ici** : `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` et `flutter build apk`, car Flutter/Dart ne sont pas installés dans l’environnement de travail. Le dépôt comprend maintenant des tests Dart pour les comportements, la saisie des notes, l’historique des modifications et le calcul pondéré; ils doivent être exécutés dans un environnement Flutter avant de considérer cette version comme compilée ou prête à installer.

## Vérification locale

Depuis la racine du projet :

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

Ne distribuez pas l’APK comme version de production avant validation sur un téléphone Android et vérification de sa signature de publication.

### Version 0.6.0 — interface refinement
The UI pass standardizes typography, spacing, card surfaces, form controls, and bottom navigation. The More screen uses responsive stacked controls to prevent the narrow text wrapping seen on small phones. Database structure and existing business logic are unchanged.
