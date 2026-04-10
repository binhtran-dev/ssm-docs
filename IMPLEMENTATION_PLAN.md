# SSM-Docs Implementation Plan

## Overview

Create a shared repository (`ssm-docs`) on `github.ascension.org/Ascension` containing:
1. **Documentation** — architecture, contracts, infrastructure, patterns, and per-service docs
2. **Dev-local setup** — Docker Compose with GCP emulators for full local E2E testing

The repo is added as a **git submodule** (`.shared-docs/`) to every service repository, tracking the `main` branch.

---

## Phase 1: Scaffold the ssm-docs Repository

### 1.1 Repository Structure

```
ssm-docs/
├── README.md
├── IMPLEMENTATION_PLAN.md
├── docs/
│   ├── architecture/
│   │   ├── README.md
│   │   ├── database-architecture.md
│   │   ├── dssc-document-service-flows.md
│   │   ├── dssc-active-fax-cloud-func-flows.md
│   │   ├── dssc-block-time-service-flows.md
│   │   ├── dssc-document-upload-handler-flows.md
│   │   └── mit-surgical-flows.md
│   ├── contracts/
│   │   ├── README.md
│   │   ├── backend-to-backend/
│   │   │   └── README.md
│   │   └── ui-to-backend/
│   │       └── README.md
│   ├── infrastructure/
│   │   ├── README.md
│   │   ├── gcp-project-architecture.md
│   │   ├── pubsub.md
│   │   ├── cloud-functions.md
│   │   ├── mongodb.md
│   │   └── authentication.md
│   ├── patterns/
│   │   ├── README.md
│   │   ├── java21-coding-standards.md
│   │   ├── lombok-conventions.md
│   │   ├── rest-conventions.md
│   │   ├── database-entity-pattern.md
│   │   ├── service-pattern.md
│   │   └── testing-pattern.md
│   └── services/
│       ├── README.md
│       ├── dssc-document-service.md
│       ├── dssc-active-fax-cloud-func.md
│       ├── dssc-block-time-service.md
│       ├── dssc-document-upload-handler.md
│       └── mit-surgical.md
├── dev-local/
│   ├── README.md
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config/
│   │   ├── pubsub-manifest.yaml        # All topics & subscriptions
│   │   ├── mongodb-init.js             # Seed databases & collections
│   │   └── gcs-buckets.yaml            # Bucket definitions
│   └── scripts/
│       ├── init-pubsub.sh              # Create topics/subs from manifest
│       ├── init-gcs.sh                 # Create buckets
│       ├── init-mongodb.sh             # Init databases
│       └── start.sh                    # Orchestrator: compose up + init
└── .gitignore
```

### 1.2 Docker Compose Services (dev-local)

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `pubsub-emulator` | `gcr.io/google.com/cloudsdktool/google-cloud-cli` | 8085 | Pub/Sub emulator |
| `fake-gcs-server` | `fsouza/fake-gcs-server` | 4443 | GCS emulator |
| `bigquery-emulator` | `ghcr.io/goccy/bigquery-emulator` | 9050 | BigQuery emulator |
| `mongodb` | `mongo:7` | 27017 | MongoDB |
| `functions-framework` | Custom Dockerfile or `gcr.io/...` | 8080 | Cloud Functions |
| `pubsub-init` | `google-cloud-cli` | — | One-shot: creates topics/subs |
| `gcs-init` | `curlimages/curl` | — | One-shot: creates buckets |
| `mongo-init` | `mongo:7` | — | One-shot: seeds databases |

### 1.3 Pub/Sub Shared Manifest

A single `pubsub-manifest.yaml` defining all topics and subscriptions across all services, derived from existing application configs:

**Topics** (17 across all services):
- `document.scan.local`, `document.status.local`
- `adsi.historical.local`, `dssc.email.local`, `metrics.event.local`
- `ssm.notification.local`, `ssm.surgeryrequest.local`, `edsl.notification.local`
- `virusscan.result.local`
- `ssm.compliance-logging.local`
- Plus provisioning & cron trigger topics

**Subscriptions** (20+ across all services):
- See `dev-local/config/pubsub-manifest.yaml` for the full manifest

---

## Phase 2: Initialize Git & Push to GitHub Enterprise

```bash
cd /Users/binhtran/work/projects/ssm/ssm-docs
git init
git add .
git commit -m "feat: initial scaffold — docs structure + dev-local setup"
```

Then create the repo on `github.ascension.org/Ascension/ssm-docs` and push:
```bash
git remote add origin git@github.ascension.org:Ascension/ssm-docs.git
git branch -M main
git push -u origin main
```

---

## Phase 3: Add Submodule to All Service Repos

Run in each service repository:
```bash
git submodule add -b main git@github.ascension.org:Ascension/ssm-docs.git .shared-docs
git commit -m "feat: add ssm-docs as shared submodule"
git push
```

**Target repositories** (6 total):
1. `dssc-document-service`
2. `dssc-active-fax-cloud-func`
3. `dssc-block-time-service`
4. `dssc-clamav-run`
5. `dssc-document-upload-handler`
6. `mit-surgical`

### Post-setup: Developer Workflow

After cloning any service repo, developers run:
```bash
git clone --recurse-submodules git@github.ascension.org:Ascension/<service>.git
# Or if already cloned:
git submodule update --init --recursive
```

To update the shared docs to latest:
```bash
git submodule update --remote .shared-docs
git add .shared-docs
git commit -m "chore: update shared docs"
```

---

## Phase 4: Validate Dev-Local Setup

```bash
cd .shared-docs/dev-local
cp .env.example .env
./scripts/start.sh
```

Validation checklist:
- [ ] MongoDB accessible at `localhost:27017` with all 3 databases
- [ ] Pub/Sub emulator running at `localhost:8085` with all topics/subs
- [ ] GCS fake server running at `localhost:4443` with all buckets
- [ ] BigQuery emulator running at `localhost:9050`
- [ ] Service can connect to local emulators with `spring.profiles.active=local`

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Submodule adds friction to `git clone` | Document `--recurse-submodules` in each repo's README |
| Pub/Sub manifest drifts from service configs | CI check or convention to update manifest when topics change |
| Emulator API parity gaps | Document known limitations per emulator |
| GitHub Enterprise repo creation requires admin | Coordinate with org admin before Phase 2 |

---

## Execution Order

1. **Scaffold repo locally** (this PR)
2. **Create repo on GitHub Enterprise** (manual — needs org admin or API token)
3. **Push initial commit**
4. **Add submodule to each service repo** (6 separate PRs or one batch)
5. **Update each service's README** with submodule usage instructions
6. **Team validates** dev-local docker-compose works E2E
