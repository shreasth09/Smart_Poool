# Smart Delivery Pooling System — Project Report

## 1. Abstract

Smart Delivery Pooling System (RouteWise) is a relational database-backed prototype for combining compatible last-mile delivery orders across supported delivery platforms. Orders with a common destination and a close delivery promise are grouped into suggested pools. When a pool is accepted, the system verifies that the orders are still pending and that an available rider supports every platform represented in the group. It then creates a delivery batch, attaches the selected orders, assigns the rider and records status changes transactionally.

The prototype includes a dashboard, operational CRUD pages, pooling workflow, batch lifecycle, a schematic Jaipur zone map and reports. Fictional sample data lets the workflow be demonstrated without partner API credentials or live GPS access.

## 2. Problem statement

Multiple delivery services may serve customers in nearby zones at similar times. Sending each compatible order on a separate trip can increase repeated travel. The project demonstrates how relational data and a simple rule-based grouping algorithm can surface candidate orders for a shared delivery run.

## 3. Objectives

- Maintain customers, platforms, riders, locations, orders and batches in a relational database.
- Enforce keys, uniqueness rules, valid statuses and referential integrity.
- Group pending orders by destination and delivery time proximity.
- Check rider/platform capability before accepting a pool.
- Record batch membership and order status history.
- Present operational and analytical information through a browser dashboard.

## 4. Technology stack

- Frontend: HTML, CSS and JavaScript.
- Backend: Node.js HTTP server and JSON API.
- Database: SQLite using the built-in `node:sqlite` module in Node.js 22.5+.
- SQL concepts: primary keys, foreign keys, unique constraints, check constraints, joins, aggregates, indexes, views and triggers.

## 5. Main modules

1. Dashboard and analytics: counts, platform mix, order lifecycle, batches, demand zones and estimated savings.
2. Master data: customers, platforms, riders and locations, with create/read/update/delete operations.
3. Order management: new orders, linked customer/platform/pickup/destination details, status and promised delivery time.
4. Pooling engine: destination matching, 75-minute tolerance, maximum four orders, rider/platform compatibility and opportunity decisions.
5. Batch lifecycle: created/active, picked up, delivered or cancelled; linked order and rider status updates.
6. Map view: schematic representation of stored Jaipur zone coordinates and sample demand counts.

## 6. Pooling algorithm

1. Read pending orders ordered by destination and promised time.
2. Select the earliest unassigned order as the seed candidate.
3. Add other pending orders with the same destination if their promised time is within 75 minutes of the seed order, until the pool reaches four orders.
4. Keep candidate groups containing at least two orders; leave single orders in the pending queue.
5. When an opportunity is accepted, re-check the status of every included order.
6. Find an available rider who has a matching row in `rider_platforms` for every platform required by the group.
7. Within one database transaction, create the delivery batch and its `batch_orders`, set orders to assigned, set the rider to on-delivery and mark the opportunity accepted. On errors, the transaction is rolled back.

## 7. Database entities and relationships

- `platforms` 1—many `orders`.
- `locations` 1—many `customers`, `riders`, pickup locations and destination locations.
- `riders` many—many `platforms` through `rider_platforms`.
- `customers` 1—many `orders`.
- `orders` many—many `delivery_batches` through `batch_orders` over time; each order can be linked to only one batch in this prototype due to the unique constraint on `batch_orders.order_id`.
- `locations` 1—many `pooling_opportunities`.
- `orders` 1—many `order_status_history` audit records.

## 8. Integrity and SQL objects

Primary and foreign keys identify records and protect relationships. UNIQUE constraints prevent duplicate platform names/codes, customer emails and rider phone numbers. CHECK constraints validate supported vehicles, statuses, ratings and non-negative order amounts. Indexes target status filtering, destination/time search, rider availability and open opportunities. Views `v_active_batches` and `v_order_summary` simplify operational joins. Triggers insert audit history when an order is created or its status changes.

SQLite does not implement stored procedures. Accordingly, procedure-like operations (generation, pool acceptance and batch status transition) are implemented as transactional application service handlers in `server/src/routes.js`.

## 9. Test cases

| Test | Expected result |
|---|---|
| Start the server | Dashboard served at `http://localhost:3000` |
| API health check | `success: true`, database connected |
| Seed database | 5 platforms, 12 locations, 25 customers, 12 riders and 50 orders |
| Search in CRUD pages | Table filters displayed rows without mutating data |
| Add/edit/delete customer | Database record is changed; duplicate email is rejected |
| Generate pooling opportunities | Groups are created from compatible pending orders |
| Accept a pool | Batch and batch-order relations are created; rider is assigned |
| Mark picked up | Batch transitions and all linked orders become picked up |
| Complete a batch | Batch and linked orders become delivered; rider becomes available |
| Delete a referenced record | Foreign keys prevent deletion where required |
| Analytics page | Aggregates and destination statistics load from the database |

## 10. Limitations and future scope

This prototype uses seeded data, rule-based proximity and estimated travel savings. A production system would require live partner APIs, real GPS/road distances, service-level agreement checks, rider dispatch authentication, customer privacy controls, route optimisation and measured cost/savings data.

## 11. Conclusion

The prototype demonstrates how a relational database, integrity rules, SQL reporting, audit triggers and transactional application logic can support a practical delivery pooling workflow. The end-to-end demonstration runs locally without partner credentials or an external database server.
