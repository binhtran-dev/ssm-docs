#!/bin/sh
# Initialize GCS buckets on fake-gcs-server.
# Reads bucket names from gcs-buckets.yaml (simple grep, no YAML parser needed).

set -e

GCS_HOST="${GCS_HOST:-http://fake-gcs-server:4443}"
BUCKET_FILE="${BUCKET_FILE:-/app/gcs-buckets.yaml}"

echo "Initializing GCS buckets on ${GCS_HOST}..."

# Extract bucket names from YAML (lines matching "- name: <bucket>")
grep '^\s*- name:' "$BUCKET_FILE" | sed 's/.*- name:\s*//' | while read -r bucket; do
    echo "  Creating bucket: ${bucket}"
    curl -sf -X POST "${GCS_HOST}/storage/v1/b" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${bucket}\"}" \
        > /dev/null 2>&1 || echo "    (already exists or error)"
done

echo "GCS init complete."
