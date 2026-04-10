// MongoDB initialization script
// Creates databases and collections for all SSM services.
// This runs automatically when the MongoDB container starts for the first time.

// ── Document Service ──────────────────────────────────
db = db.getSiblingDB('document-service');
db.createCollection('documents');
db.createCollection('scanResults');
print('Created database: document-service');

// ── Block Time Service ────────────────────────────────
db = db.getSiblingDB('dssc-block-time-service');
db.createCollection('blockTimes');
db.createCollection('releases');
db.createCollection('schedules');
print('Created database: dssc-block-time-service');

// ── MIT Surgical (Case Tracker) ───────────────────────
db = db.getSiblingDB('casetracker');
db.createCollection('cases');
db.createCollection('surgeons');
db.createCollection('practices');
db.createCollection('hospitalUnits');
db.createCollection('rooms');
db.createCollection('users');
db.createCollection('notifications');
print('Created database: casetracker');

print('\nMongoDB init complete: 3 databases created.');
