# RouteWise — Smart Delivery Pooling System

A full-stack college DBMS project that demonstrates cross-platform last-mile delivery pooling. The app has a responsive operations dashboard, a relational SQLite database, a Node.js API, sample Jaipur delivery data, transactional pool acceptance, audit triggers, SQL views and analytics.

## Start here (Windows)

**Requirements:** Node.js **22.5 or newer**. The application uses Node's built-in SQLite support and has no third-party runtime dependencies.

1. Extract the project ZIP into a folder (for example, `Desktop\smart-delivery-pooling-system`).
2. Make sure Node.js **22.5 or newer** is installed. If it is missing/older, install the current Node.js 22 LTS release from the official Node.js website.
3. Double-click **`RUN_PROJECT.bat`**. It checks ports 3000–3010, chooses a free port (so an older project on port 3000 will not hijack the browser), starts the local server in a terminal, and opens the dashboard. Leave the server terminal open while presenting. The terminal prints the exact URL.
4. If Windows blocks the batch file or you prefer manual startup, open a terminal in the extracted folder, run `node --version`, then run `npm start` and visit **http://localhost:3000**.

The first start automatically creates `server/data/pooling.db`, applies the schema, and inserts sample records. **Do not run `npm install`.** To stop, press `Ctrl+C` in the server terminal. The local database is kept between runs.

## Demo walkthrough (about 3–5 minutes)

1. **Overview:** show the order, rider, and batch KPIs and delivery-platform volumes.
2. **Pooling engine:** click **Generate opportunities**. The algorithm groups pending orders that share a destination and are within a 75-minute window, with a maximum of four orders per group.
3. Click **Accept pool** on a suggestion. The server checks that orders are still pending and finds an available rider registered for all platforms represented in the group. In one database transaction it creates a batch, links the orders, updates their statuses, assigns the rider and marks the opportunity accepted.
4. **Delivery batches:** mark the new batch **Picked up**, then **Complete**. The linked orders become delivered and the rider becomes available again.
5. **Orders / Customers / Riders / Platforms / Locations:** create, edit, search and delete records. Some records cannot be deleted while other records depend on them; the database protects those relationships.
6. **Jaipur zone map:** explain that this is a schematic map of seeded coordinates, not live GPS tracking.
7. **Analytics & reports:** show platform totals, status distribution, destination demand and pooling estimates.

## Application architecture

- **Frontend:** HTML, CSS and browser JavaScript. No bundler or package download is needed.
- **Backend:** Node.js HTTP server with JSON API routes in `server/src/routes.js`.
- **Database:** SQLite via the built-in `node:sqlite` module. The database is created automatically on first run.
- **Data design:** platforms, locations, customers, riders, rider-platform relationships, orders, delivery batches, batch-orders, pooling opportunities and order-status history.
- **Integrity:** foreign keys, unique constraints, status checks, indexes, transactional updates, and triggers to audit status changes.

## API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Server and database status |
| GET | `/api/dashboard` | KPI cards and platform/order summaries |
| GET | `/api/analytics` | Platform, status, batch and destination analytics |
| GET/POST | `/api/customers` | List / create customers |
| GET/PUT/DELETE | `/api/customers/:id` | Read / update / delete a customer |
| GET/POST | `/api/platforms` | List / create platforms |
| GET/PUT/DELETE | `/api/platforms/:id` | Read / update / delete a platform |
| GET/POST | `/api/riders` | List / create riders |
| GET/PUT/DELETE | `/api/riders/:id` | Read / update / delete a rider |
| GET/POST | `/api/locations` | List / create locations |
| GET/PUT/DELETE | `/api/locations/:id` | Read / update / delete a location |
| GET/POST | `/api/orders` | List / create orders |
| GET/PUT/DELETE | `/api/orders/:id` | Read / update / delete an order |
| GET | `/api/batches` | List delivery batches |
| PATCH | `/api/batches/:id/status` | Update batch to picked up, delivered, or cancelled |
| GET | `/api/pooling/opportunities` | List open pooling opportunities |
| POST | `/api/pooling/generate` | Generate new pool suggestions |
| POST | `/api/pooling/opportunities/:id/accept` | Validate and assign a pool |
| POST | `/api/pooling/opportunities/:id/dismiss` | Dismiss a suggestion |
| GET | `/api/map/locations` | Locations with demand and nearby rider counts |
| GET | `/api/lookup` | Form dropdown data |

## Database files

- `server/database/schema.sql` — schema applied automatically by the app.
- `database/schema.sql` — copy of the schema for manual inspection/submission.
- `database/seed.sql` — sample records for a fresh schema.
- `database/setup.sql` — combined schema + seed script for a fresh SQLite database.
- `database/queries.sql` — 30 example reporting and relational queries.
- `database/views.sql`, `database/triggers.sql`, `database/indexes.sql` — standalone object scripts (also included in `schema.sql`).
- `database/procedures.sql` — explains the procedure-style transactional flows implemented by the API. SQLite itself has no `CREATE PROCEDURE` syntax.

For a clean database reset, stop the server and delete `server/data/pooling.db` (and any `.db-wal` / `.db-shm` files). Restart with `npm start`; the sample database is recreated. This permanently discards local changes.

## Notes and limitations

- Sample names, orders, phone numbers and locations are fictional demonstration data.
- The map coordinates and trip-saving percentages are illustrative; the app does not use live device GPS, partner APIs, or production tracking.
- Pool acceptance requires a rider to support every platform present in the pool. The seeded data includes multi-platform riders so this can be demonstrated immediately.
- SQLite does not support stored procedures. Multi-step pooling and batch workflows are implemented as transactional server operations; database triggers and views are real SQLite objects.
- No external account, payment, or customer data is accessed.
