# Troubleshooting

## `./backend/scripts/setup-local.sh` says a command is missing

Install Homebrew packages from the README and add the versioned MySQL and PostgreSQL utilities to this Terminal session:

```sh
export PATH="$(brew --prefix mysql)/bin:$(brew --prefix postgresql@18)/bin:$PATH"
```

Then run `./backend/scripts/setup-local.sh` again. The script uses Homebrew MySQL tools, `initdb`, `pg_ctl`, and `psql`.

## MySQL will not start

Check the project-specific log and port:

```sh
tail -60 .local-data/mysql.log
mysqladmin --protocol=tcp --host=127.0.0.1 --port=3307 --user=root ping
```

This project uses an isolated MySQL data directory under `.local-data/mysql`, port `3307`, and socket `/tmp/fleet-logistics-mysql.sock`. If another process already owns port 3307, stop that process or change the project port consistently in `.env.local` and the scripts. Do not point the test suite at another database.

## PostgreSQL or `vector` extension unavailable

```sh
pg_isready --host=127.0.0.1 --port=5433
psql --host=127.0.0.1 --port=5433 --username=postgres --dbname=fleet_vectors \
  --command="SELECT extversion FROM pg_extension WHERE extname='vector'"
```

If the extension is absent, confirm `pgvector` is installed for the same Homebrew PostgreSQL major version, then rerun `./backend/scripts/init-databases.sh`. The script enables `vector` in the project database.

## Vector sync errors during incident save or search

Embeddings are computed deterministically in-process inside `backend/lib/vector.ts` (no external daemon needed), so sync failures are almost always caused by PostgreSQL (`:5433`) being stopped or `.env.local` missing `PG_VECTOR_URL`. Verify PostgreSQL is running and retry:

```sh
pg_isready --host=127.0.0.1 --port=5433
npm run db:sync-vectors
```

If an incident saved in MySQL but vector sync failed, the MySQL outbox (`incident_vector_jobs`) retains the failed job and the Incidents page reports the error so it can be retried once PostgreSQL is up.

## Login does not work

- Check that `.env.local` has a `SESSION_SECRET` of at least 32 characters and the right MySQL port, user, password, and database.
- Confirm that demo accounts are seeded (`npm run db:seed`), or create an initial Admin after `./backend/scripts/setup-local.sh`:

  ```sh
  FLEET_ADMIN_PASSWORD='your-chosen-password' npm run admin:create -- \
    --name "Fleet Administrator" --email admin@example.local
  ```

- The first-account command intentionally fails after one or more users exist. Use **User management** while signed in as Admin for additional accounts.
- Sessions expire after 12 hours. Sign in again if the cookie has expired.

## Port 3000 is already in use

Close the other local app that owns port 3000 before starting FleetDesk. The project expects the default local address `http://localhost:3000`; keeping a single Next process avoids accidentally testing an older instance.

## Clear a stale vector job

Do not delete the source incident to fix an embedding error. Check the error on the Incidents page, ensure PostgreSQL (`:5433`) is running, and run `npm run db:sync-vectors`. Job state and source text remain in MySQL so the operation can be retried cleanly.

## Integration tests fail to connect

The API suite requires the app and both local databases. Start MySQL (`:3307`) and PostgreSQL (`:5433`), start `npm run dev`, export credentials for an Admin, then run `npm run test:integration`. It uses records prefixed `TST-` and performs cleanup after the test.
