# Test results

Checked in the project build environment on 13 October 2026.

- `npm run check` — passed (Node.js syntax check on the server modules and browser JavaScript).
- Live `GET /api/health` — passed; SQLite connection reported as connected.
- Initial seeded record counts — passed: 5 platforms, 12 locations, 25 customers, 12 riders, 50 orders and 5 historical batches.
- CRUD smoke test — passed: create, update, read and delete a temporary customer.
- Pool generation — passed; multiple opportunity groups were produced from pending orders.
- Pool acceptance — passed; a compatible rider and active delivery batch were assigned to a multi-order pool.
- Batch lifecycle — passed: active → picked_up → delivered; linked orders became delivered and the batch returned linked order details.
- Analytics endpoint — passed.
- Manual SQL validation — `database/setup.sql` loaded successfully into a fresh temporary SQLite DB, and all 30 statements in `database/queries.sql` executed successfully.
- Static content — `/`, `/src/app.js` and `/src/styles.css` returned HTTP 200.

A full browser screenshot test could not be completed in the isolated environment because its Chromium session blocks localhost navigation with `ERR_BLOCKED_BY_ADMINISTRATOR`. This does not indicate an application HTTP failure: the same local endpoints were verified using HTTP requests and application smoke tests. Please open `RUN_PROJECT.bat` on the target Windows machine for the final visual check.
