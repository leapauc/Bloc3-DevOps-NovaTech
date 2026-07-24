# Audit J1 — Équipe entrante
**Date** : 23 juillet 2026 · **Périmètre** : repo complet (code, historique Git, CI/CD, infra, docs)

Cet audit suit la grille de `CONSIGNES-ETUDIANTS.md`. Il recoupe le rapport Partech
(`docs/audit-partech-septembre-2024.md`) et le post-mortem P1 (`docs/incident-aout-2024.md`),
et ajoute les éléments qu'ils ne couvraient pas : middleware d'auth mort dans le code (et pas
seulement "désactivé"), secrets en dur en fallback dans le code source, credentials admin qui
traînent sur une branche non mergée, et deux fichiers non commités dans l'arbre de travail actuel.

## A. Sécurité

### Critique
| # | Constat | Où |
|---|---|---|
| 1 | `.env` de prod commité dans Git depuis le 16/09/2021 (DB, JWT, AWS, Stripe live, SendGrid, SMTP) — toujours dans `HEAD`, `.gitignore` ne l'exclut pas | `.env`, `.gitignore` |
| 2 | Injection SQL par concaténation directe sur le login (`email`) | `services/auth/src/index.js:20-22` |
| 3 | `POST /paie/migrate` exécute des `ALTER TABLE`/`UPDATE` en prod sans authentification — cause directe de l'incident P1 du 14/15 août | `services/paie/src/index.js:33-45` |
| 4 | `GET /conges/debug/all` expose la jointure complète congés+employés sans auth, ajouté en urgence oct. 2023, jamais retiré malgré un TODO explicite | `services/conges/src/index.js:32-35` |
| 5 | Le middleware d'auth existe mais **n'est jamais branché** dans le gateway — aucune route proxyée (`/api/auth`, `/api/paie`, `/api/conges`, `/api/recrutement`) n'est protégée. Ce n'est pas une désactivation temporaire : c'est un middleware mort depuis le commit `06445bd` (mars 2024) | `services/api-gateway/src/index.js`, `services/api-gateway/src/middleware/auth.js` |
| 6 | CORS totalement ouvert (`Origin`/`Methods`/`Headers: *`) sur tout le gateway | `services/api-gateway/src/index.js:6-11` |
| 7 | `JWT_SECRET` loggé en clair au démarrage, dans **deux** services (gateway + auth) | `services/api-gateway/src/index.js:27`, `services/auth/src/index.js:48` |
| 8 | Secrets de prod en dur comme valeurs par défaut dans le code (`DB_PASSWORD`, `JWT_SECRET`, `STRIPE_SECRET_KEY`) — même en régénérant `.env`, le code retombe sur l'ancien secret si la variable manque | `services/auth/src/index.js:14,29,39`, `services/paie/src/index.js:24` |
| 9 | Script de déploiement avec mot de passe SSH en clair, IP en dur, `StrictHostKeyChecking=no` | `scripts/deploy.sh` |
| 10 | Credentials admin fonctionnels en clair (`admin@novatech.io` / `Admin2024!`) dans un script de test manuel sur la branche `dev`, jamais mergée mais toujours présente dans le repo | `dev:services/conges/src/test-manual.js` |

### Élevé
- Aucune authentification API — l'architecture entière suppose la confiance du réseau, pas seulement quelques routes oubliées.
- Upload de CV (`multer`) sans validation de type ni de taille, nom de fichier original non assaini (`services/recrutement/src/index.js:9-13`) → risque d'écrasement/traversal.
- Le handler d'erreur du gateway renvoie la stack trace au client (`services/api-gateway/src/index.js:20-23`).
- 0 % de couverture de tests backend ; les 2 tests frontend existants sont des coquilles vides (`expect(true).toBe(true)`), cassés depuis une refacto de nov. 2023, jamais réparés malgré 2 TODO successifs de 2 auteurs différents.
- Pas de TLS, ni en prod ni en staging (`nginx/hrflow.conf`) — tokens et mots de passe voyagent en clair.
- `/logs/` servi publiquement avec `autoindex on` — expose potentiellement les `JWT_SECRET` loggés au point 7.
- Staging accessible sans aucune barrière (confirme l'incident de juin 2024 cité par Partech).

## B. Historique Git

- **3 branches** : `main`, `dev` (1 commit d'avance, jamais mergé), `feature/recrutement-v2` (1 commit d'avance, jamais mergé).
- **Auteurs** : Théo Marchand (lead dev, l'essentiel de l'infra + toute la doc de handoff), Karim Bouaziz (CEO — commit initial *et* post-mortem, signe qu'il code/documente directement), Camille Dreyfus (frontend, endpoint debug congés, WIP recrutement), Rayan Ould (recrutement, désactivation du middleware auth, script de test avec credentials), Mohamed Benali (stagiaire, tests écrits une fois en juillet 2023 puis plus jamais touchés).
- **Pas de vrai commit de revert**, mais `06445bd "temp: désactivation middleware auth"` est une régression jamais rétablie — le mot "temp" date de mars 2024, l'audit Partech de septembre 2024 la liste encore comme active.
- **Branches abandonnées** : `dev` contient un script marqué *"À ne pas laisser dans le repo !!!"* avec des credentials qui fonctionnent ; `feature/recrutement-v2` est un stub de matching CV qui renvoie `Math.random()`.
- **Fichier le plus disputé** : `services/paie/src/index.js`, touché par 3 personnes à des dates différentes sans qu'aucun test n'accompagne les changements — c'est le service qui déclenche des virements Stripe réels.
- **Chronologie** : doc gelée entre 2022 et 2023, incident P1 le 14/15 août 2024, audit Partech le 18 septembre 2024, et — le même jour, 27 septembre 2024 — les 3 documents de handoff (Partech, consignes, guide d'historique) sont commités. La passation intervient donc immédiatement après un audit externe accablant et un an après le départ du CTO consécutif à l'incident.

## C. Pipeline CI/CD

`.github/workflows/deploy.yml` : un seul job, déclenché uniquement sur push vers `main`.
Étapes réelles : checkout → Node **16** (EOL depuis sept. 2023) → `npm install` → build du frontend
uniquement → **tests commentés** → déploiement SSH par mot de passe → `pm2 restart all`.

Manque : lint, `npm audit`/SAST, gate de tests, déploiement staging (alors que l'environnement
staging existe dans la config Nginx !), validation manuelle avant prod, rollback automatisé,
notification d'échec, protection de branche sur `main`.

## D. Infrastructure

- Déploiement manuel/CI par SSH mot de passe vers un unique VPS OVH, `git pull && pm2 restart all` — pas de conteneurisation, pas de health-check avant bascule, point de défaillance unique.
- **Aucun monitoring, aucun alerting** trouvé dans le repo — cohérent avec la détection de l'incident P1 par un client à 2h15 plutôt que par de l'outillage interne.
- Backups : rien d'automatisé dans le repo ; le post-mortem mentionne une restauration depuis une sauvegarde de 22h30 dont la fréquence/le test ne sont documentés nulle part.
- Nginx : pas de TLS, `/logs/` public, aucun header de sécurité, staging non isolé.

## E. Documentation

- `README.md` : dernière mise à jour mars 2022, référence un `.env.example` qui n'existe pas, "Déploiement : voir Théo" — bus factor critique au moment même où Théo part.
- `docs/architecture.md` : TODO depuis 2021, liste les ports mais aucun flux de données.
- Les documents d'audit (Partech, post-mortem) sont eux de bonne qualité — mais leurs plans d'action sont explicitement marqués non réalisés.
- Pas d'OpenAPI, pas de runbook d'incident/rollback.

## Divers — état de l'arbre de travail au moment de l'audit
- `package-lock.json` non suivi par Git → versions de dépendances non reproductibles en CI.
- `scripts/deploy.sh` a perdu son bit d'exécution dans la copie de travail (mode 100755 → 100644, non commité) — à vérifier avant de committer quoi que ce soit sur ce fichier.

## Plan de remédiation (ordonné)

**Phase 0 — immédiat, avant tout autre travail**
1. ⚠️ Rotation de **tous** les secrets ayant transité par `.env`/l'historique Git (DB, JWT, AWS, Stripe, SendGrid, SMTP, Redis) — les considérer compromis, repo privé ou non. *Fait côté repo (nouveaux secrets JWT/DB de dev générés dans `.env`, gitignoré). Reste à faire hors repo, par une personne ayant accès aux consoles AWS/Stripe/SendGrid/OVH : révoquer et régénérer les clés/mots de passe réels.*
2. ✅ Retirer `.env` du suivi Git, l'ajouter au `.gitignore`, fournir `.env.example` sans valeur réelle. *Fait. La réécriture d'historique (BFG/`git filter-repo`) reste volontairement **non faite** — elle réécrit l'historique partagé et nécessite un accord explicite de l'équipe avant un force-push.*
3. ✅ Supprimer les secrets en dur utilisés comme fallback dans le code (`|| 'novatech_jwt_...'`, etc.) — le service échoue maintenant si la variable d'env manque, au lieu de retomber sur une valeur connue.
4. ✅ `/paie/migrate` et `/conges/debug/all` exigent désormais un JWT valide avec `role: admin` (vérifié directement dans chaque service, pas seulement au niveau du gateway).
5. ✅ Middleware d'auth rebranché dans le gateway sur `/api/paie`, `/api/conges`, `/api/recrutement` (`/api/auth` reste public : c'est la route de login/verify elle-même). Le bug d'expiration de token qui avait motivé sa désactivation en mars 2024 n'est pas encore corrigé — à surveiller en premier retour d'usage.

**Phase 1 — J1/J2 : arrêter l'hémorragie**
6. ✅ Injection SQL corrigée (requête paramétrée) sur `/auth/login`.
7. ✅ CORS restreint à une liste blanche d'origines (`CORS_ALLOWED_ORIGINS`, prod/staging par défaut), au lieu de `*`.
8. ✅ `console.log('JWT_SECRET', ...)` retiré des deux services (`auth`, `api-gateway`).
9. ✅ `/logs/` retiré de la config Nginx (pas seulement `autoindex off` — la route n'existe plus).
10. ✅ Staging protégé par `auth_basic` dans Nginx. *Stopgap : le fichier `/etc/nginx/.htpasswd-staging` doit être généré côté serveur (`htpasswd -c`) — ça n'existe pas dans ce repo. IP allowlist/VPN restent prévus en Phase 3 pour une protection plus robuste.*

**Phase 2 — semaine 1 : pipeline et qualité**
11. ✅ CI reconstruite en 5 stages (`build → test → security → staging → prod`, jobs séparés + `pull_request` en plus de `push`). *La protection de branche `main` (statuts obligatoires) est une config GitHub (Settings → Branches), pas un fichier — nécessite un accès admin que je n'ai pas.*
12. ✅ Node passé à la version LTS 22 partout (`engines` + CI). `npm audit --omit=dev --audit-level=high` ajouté en CI pour chaque service. En le faisant tourner réellement, il a détecté et fait corriger 2 vraies vulnérabilités : `jsonwebtoken@8.5.1` (high, bump → 9.0.2) et `bcrypt@5.1.0` via `node-tar`/`node-pre-gyp` (critique, bump → 6.0.0).
13. ✅ Tests réels ajoutés et exécutés avec succès : 6 tests `/auth` (login, verify, régression injection SQL), 4 tests `/paie` (heures-sup, garde admin `/migrate`), 4 tests `/conges` (solde, garde admin `/debug/all`), 3 tests frontend `Login.jsx` réparés (rendu, erreur, stockage du token) — remplacent les `expect(true).toBe(true)` vides.

**Phase 3 — semaines 2-4 : durcissement infra**
14. ✅ TLS activé sur prod + staging (config Let's Encrypt/certbot, syntaxe validée avec `nginx -t`). ✅ SSH par clé à la place du mot de passe (CI + `scripts/deploy.sh`, `StrictHostKeyChecking=yes` rétabli). ✅ Rollback automatique en CI si le health-check échoue (capture du SHA précédent, `git reset --hard` + restart). *Migration vers un vrai secrets manager (Vault/AWS Secrets Manager) non faite : nécessite un compte et des accès que je n'ai pas — les secrets restent dans les secrets GitHub Actions, déjà mieux qu'en clair dans le repo.*
15. ✅ Monitoring minimal : workflow programmé qui ping `/health` toutes les 5 min et alerte via webhook (`.github/workflows/uptime-check.yml`) — pas un vrai APM/astreinte, mais un filet qui n'existait pas du tout. ✅ Backups horaires (`scripts/backup-db.sh`) + restauration (`scripts/restore-db.sh`), **testés pour de vrai** : backup → suppression d'une table sur un Postgres jetable → restauration → données récupérées à l'identique.

**Phase 4 — continu**
16. ✅ README et `architecture.md` réécrits pour refléter le code réel (setup multi-services, ports, schéma de données reconstitué et vérifié, diagrammes). `docs/RUNBOOK.md` complété avec les sections déploiement normal et incident (avait déjà rollback/restauration depuis la Phase 3). Effet de bord : `cp .env.pmn .env` ne servait à rien avant — aucun service ne lisait `.env` (pas de `dotenv`). Ajouté et testé (`require('dotenv').config()` avec un chemin basé sur `__dirname`, pour marcher quel que soit le dossier depuis lequel le service est lancé) — les instructions du README sont maintenant vraies, pas juste écrites.
17. ⏸️ Décision prise avec l'équipe : les branches `dev` et `feature/recrutement-v2` ne sont **pas** supprimées (choix explicite, pas un oubli). Une branche `PMN` a été créée à partir de l'état actuel de `main` comme point de sauvegarde du travail de remédiation.

## Architecture cible du pipeline (5 stages)

`build → test → security → staging → prod`, avec porte de passage obligatoire entre chaque étape
(voir diagramme dans le dossier visuel). Test bloque si rouge ; security bloque sur CVE
critique/élevée ; staging exige un smoke test qui passe ; prod exige une validation manuelle et
est suivi d'un rollout avec health-check et rollback automatique.
