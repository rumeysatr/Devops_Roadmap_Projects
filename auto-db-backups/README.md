# Automated MongoDB Backups → Cloudflare R2

A scheduled backup pipeline for a MongoDB database running in Docker on an
AWS EC2 instance. Every **12 hours** the `school` database is dumped with
`mongodump`, packaged into a timestamped `tar.gz` archive with a SHA-256
checksum, and uploaded to **Cloudflare R2** (S3-compatible object storage).
A `restore.sh` script can pull the **latest** backup back down, verify its
integrity, and rebuild the database with one command.

> Built as an intermediate DevOps exercise covering EC2, Docker, object
> storage, shell scripting, and cron — from nothing to a verified
> disaster-recovery cycle.

## Architecture

```
┌─────────────────── EC2 (Ubuntu 24.04, t3.micro) ───────────────────┐
│                                                                    │
│   cron (0 */12 * * *)                                              │
│     └── backup.sh                                                  │
│           ├── mongodump ──► 127.0.0.1:27017 ──► MongoDB 8 (Docker) │
│           ├── tar.gz archive + sha256 checksum                     │
│           └── aws s3 cp ────────► Cloudflare R2 (bucket: db-backups)│
│                                                                    │
│   restore.sh (manual, on demand): R2 → download →                  │
│        verify checksum → mongorestore --drop                       │
└────────────────────────────────────────────────────────────────────┘
```

## Requirements vs. Implementation

| Requirement | Status | Evidence |
|---|---|---|
| EC2 server with MongoDB in Docker + seed data | ✅ | Containerized MongoDB 8, `school.students` seeded with 10 records, data persisted in a named volume |
| `backup.sh`: mongodump → tarball → upload | ✅ | Produces `backup_YYYYMMDD_HHMMSS.tar.gz` + `.sha256` locally, uploads both to R2 |
| Automatic backups twice a day | ✅ | crontab entry `0 */12 * * *` (00:00 and 12:00 UTC = 03:00 and 15:00 TRT); proven first with a `*/2` test schedule |
| Restore script (stretch goal) | ✅ | `restore.sh` finds the newest archive by name, verifies checksum, restores with `--drop` |
| End-to-end disaster simulation | ✅ | Inserted an 11th record → backed up → dropped the database (0 documents) → restored → **11 documents back** |

## Pipeline (backup.sh)

1. `set -euo pipefail` — any failed step aborts the run; a broken step never
   results in a half-finished upload.
2. The script resolves its **own directory** via `BASH_SOURCE` and loads
   `.env` from there — so it behaves identically whether invoked from a
   shell, a different directory, or cron.
3. `mongodump` writes to a fresh `mktemp -d` scratch directory.
4. The dump is packed with `tar -czf` and hashed with `sha256sum`.
5. Archive + checksum are uploaded to R2 with `aws s3 cp --endpoint-url`.
6. Local retention: archives older than 7 days are deleted from the server
   (R2 copies are kept).

## Pipeline (restore.sh)

1. Lists the bucket, filters archive names, and picks the latest — the
   timestamped naming scheme makes alphabetical order == chronological order.
2. Downloads the archive and its checksum, runs `sha256sum -c` — a corrupted
   download is refused before it can touch the database.
3. Extracts and runs `mongorestore --db school --drop` — replaces the current
   collection so partial or duplicated data cannot survive a restore.

## Project Structure

```
auto-db-backups/
├── backup.sh           # mongodump → tar.gz + sha256 → R2 upload
├── restore.sh          # latest R2 archive → verify → mongorestore --drop
├── docker-compose.yml  # MongoDB 8, port bound to 127.0.0.1 only, named volume
├── seed.js             # inserts 10 sample students into school.students
├── docs/               # step-by-step build notes per phase (Turkish)
└── .env                # R2 credentials — never committed (gitignored, chmod 600)
```

## Setup

Full build notes live in [`docs/`](docs/) (in Turkish), one document per step:

1. [EC2 + SSH](docs/01-aws-ec2.md) — instance, key pair, security group, ssh config
2. [Docker + MongoDB](docs/02-mongodb-docker.md) — install, compose up, seed
3. [Cloudflare R2](docs/03-cloudflare-r2.md) — bucket, least-privilege API token, AWS CLI
4. [backup.sh](docs/04-backup-script.md) — dump → tar → upload
5. [cron](docs/05-cron.md) — 12-hour schedule with proof
6. [restore.sh](docs/06-restore.md) — verified recovery (stretch goal)
7. [Verification](docs/07-verification.md) — end-to-end disaster simulation

## Usage

```bash
# manual backup
./backup.sh

# restore the latest backup from R2
./restore.sh

# quick database check
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
```

The cron entry that ran the automated schedule:

```
0 */12 * * * /home/ubuntu/Devops_Roadmap_Projects/auto-db-backups/backup.sh >> /home/ubuntu/backups/cron.log 2>&1
```

## Security & Design Decisions

- **No public database.** MongoDB's port is bound to `127.0.0.1` inside the
  container, and the EC2 security group has no rule for 27017 — defense in
  depth across two layers.
- **Least-privilege storage credentials.** The R2 token can only read/write
  objects in the `db-backups` bucket; it cannot even list other buckets.
  (Side effect: account-wide `aws s3 ls` is denied — verification commands are
  bucket-scoped on purpose.)
- **Secrets never leave the machine.** Credentials live in a server-side
  `.env` (mode 600, gitignored), loaded by the scripts at runtime.
- **Integrity checks.** Every archive carries a SHA-256 checksum; restore
  refuses to run against a mismatched file.
- **UTC everywhere.** Timestamps, cron schedule, and file names all use UTC —
  server, logs, and object names stay consistent.

## Screenshots

<!-- add images, then uncomment:
| R2 bucket contents | cron.log — automatic triggers | disaster simulation |
|---|---|---|
| ![R2](screenshots/r2-bucket.png) | ![cron](screenshots/cron-log.png) | ![disaster](screenshots/disaster-sim.png) |
-->

## Notes & Gotchas (learned the hard way)

- Ubuntu 24.04 no longer ships `awscli` as an apt package (universe has no
  candidate) — the AWS CLI v2 must be installed from the official zip.
- R2 tokens scoped to a specific bucket cannot call `ListBuckets`, so
  `aws s3 ls` without a bucket name fails by design — not an error.
- cron runs with a minimal environment: absolute paths and in-script
  `.env` loading are what keep the job working from any context.
- Exported env vars do not survive across SSH sessions — re-source `.env`
  after every new login.

## Current State

The demo environment is parked: the cron job was removed and the MongoDB
container was stopped, while the EC2 instance itself stays running. The
environment is two commands away from being live again:

```bash
docker start mongo     # bring MongoDB back
crontab -e             # re-add the 12h schedule (see Usage above)
```

Archives in R2 (including the final one created during the disaster
simulation) remain restorable at any time.