# SSM Shared Docs & Dev-Local Setup

Shared documentation and local development environment for all SSM platform services.

## Repository Structure

```
docs/           — Architecture, contracts, infrastructure, patterns, and service docs
dev-local/      — Docker Compose stack with GCP emulators for local E2E testing
```

## Usage as Git Submodule

This repo is included as a submodule (`.shared-docs/`) in every service repository.

### Cloning a service repo with the submodule

```bash
git clone --recurse-submodules git@github.ascension.org:Ascension/<service-repo>.git
```

### If already cloned without submodules

```bash
git submodule update --init --recursive
```

### Updating to the latest shared docs

```bash
git submodule update --remote .shared-docs
git add .shared-docs
git commit -m "chore: update shared docs to latest"
```

## Dev-Local Setup

See [dev-local/README.md](dev-local/README.md) for full instructions.

Quick start:
```bash
cd dev-local
cp .env.example .env
./scripts/start.sh
```

## Services Covered

| Service | Description |
|---------|-------------|
| dssc-document-service | Document management and virus scanning |
| dssc-active-fax-cloud-func | Cloud Function for processing RightFax files |
| dssc-block-time-service | Block time and surgical scheduling |
| dssc-document-upload-handler | Document upload and virus scan result handling |
| mit-surgical | Surgical scheduler management (case tracker) |
| dssc-clamav-run | ClamAV malware scanner on Cloud Run |
