# Tests and verification

## Commands

Run checks from the project root:

```sh
npm run typecheck
npm run lint
npm test
npm run build
```

The API integration suite exercises the live app and real local services. Start the isolated MySQL (`:3307`) and PostgreSQL (`:5433`) data stores and Next.js (`npm run dev` or `npm run start`) first (incident vector embeddings run in-process via `backend/lib/vector.ts`, with no external daemon required). Then:

```sh
export TEST_ADMIN_EMAIL=demo-admin@fleetdesk.local
export TEST_ADMIN_PASSWORD='admin12345678'
npm run test:integration
unset TEST_ADMIN_EMAIL TEST_ADMIN_PASSWORD
```

The test uses unique `TST-` identifiers, verifies records through both HTTP and SQL, and cleans up test-created data. The SQL integration test must only run against this project’s local databases.

## Unit cases

`tests/core.test.ts` contains eight unit tests covering:

- Schema validation, normalization, positive quantities, and valid trip/shipment IDs.
- Legal/illegal shipment and trip status transitions.
- Salted scrypt password verification and rejection of an incorrect password.
- PNG signature detection, spoofed image rejection, safe filename handling, and the 5 MiB maximum.
- Empty pgvector results, similarity conversion, and suppression of vector IDs without a matching current MySQL incident.
- Conversion of ISO timestamps to MySQL UTC `DATETIME` values.

## API integration cases

`tests/api.integration.test.ts` runs against MySQL 9.7.1, PostgreSQL 18.6 + pgvector 0.8.7, the in-process 768-dimensional embedding generator (`backend/lib/vector.ts`), and Next.js on port 3000. Its end-to-end scenario includes assertions for:

1. App startup (`GET /login`), invalid credentials (`401`), and successful Admin login (`200`).
2. Admin-only user routes, Admin-created Operations account, and allowed/denied (`403`) Operations requests.
3. Vehicle create/read/update, server-side invalid capacity rejection, and driver creation/read.
4. Shipment creation, invalid direct transition to delivered (`409`), and MySQL FULLTEXT filtering.
5. Trip creation, missing vehicle assignment rejection, valid assignment, active resource conflict rejection, and direct SQL verification that the failed trip remains `planned` with no assignments.
6. Trip progression updates linked shipments to `in_transit` and then `delivered`.
7. Maintenance and fuel expense creation/read.
8. Image rejection when MIME/name are spoofed; upload of the actual local sample image; byte-for-byte comparison between uploaded bytes, MySQL `image_data`, and retrieved response; replacement and deletion.
9. Incident create; MySQL `embedding_status='synced'`; semantic pgvector search of a natural-language query; real result/score checks; invalid short query (`400`); incident/vector deletion.

The empty vector result path is additionally covered by the unit test for `mergeVectorMatches([], [])`.

## Results observed for this build

Verified on 2026-11-17:

| Check | Result |
| --- | --- |
| `npm run typecheck` | Passed (0 errors). |
| `npm run lint` | Passed (0 errors, 0 warnings). |
| `npm test` | Passed: 8/8 unit tests. |
| `npm run build` | Passed: optimized Next.js production webpack build (34 routes). |
| `npm run test:integration` | Passed: 1 full end-to-end scenario against live MySQL (`:3307`), PostgreSQL (`:5433`), and Next.js (`:3000`). |
| Local seed and vector sync | Seed populates 10 vehicles, 10 drivers, 10 shipments, 10 incidents, 30 `MEDIUMBLOB` images, and both RBAC demo accounts; incident vectors sync cleanly to PostgreSQL `pgvector` with 0 failures. |
| Image BLOB verification | Integration test confirmed exact byte equality before upload, in MySQL `image_data`, and after HTTP retrieval. |

Tested local runtime versions: Node.js `v26.8.2`, npm `11.19.1`, MySQL `9.7.1`, PostgreSQL `18.6`, and `pgvector` `0.8.7`. Runtime versions may change as package managers publish updates.

## Visual & browser verification

Visual documentation stored in the repository:
- Chen Notation ER Diagram: `ER diagram.png`
- Vehicles page (`MEDIUMBLOB` image thumbnails): `docs/screenshots/website-vehicles.png`
- Shipments page (`FULLTEXT` search + `MEDIUMBLOB` cargo images): `docs/screenshots/website-shipments.png`
- Incidents page (`MEDIUMBLOB` evidence + vector sync state): `docs/screenshots/website-incidents.png`

## Scope and limitations

- The integration suite hits the local Next.js server and a dedicated project data directory (`.local-data/`); it does not exercise a remote or production deployment.
- Stored procedure row locks (`SELECT ... FOR UPDATE`) and eligibility rules are exercised sequentially through valid and conflicting assignment requests.
