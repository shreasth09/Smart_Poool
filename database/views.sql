-- Run after schema.sql. These views are included in schema.sql already.
CREATE VIEW IF NOT EXISTS v_active_batches AS
SELECT b.id,b.batch_code,b.status,b.total_orders,b.estimated_distance_km,b.estimated_savings_percent,b.created_at,
       r.name AS rider_name,l.name AS destination,l.area AS destination_area
FROM delivery_batches b LEFT JOIN riders r ON r.id=b.rider_id JOIN locations l ON l.id=b.destination_location_id
WHERE b.status IN ('active','picked_up');
CREATE VIEW IF NOT EXISTS v_order_summary AS
SELECT o.id,o.order_code,c.name AS customer_name,p.name AS platform_name,src.name AS pickup_location,
       dst.name AS destination_location,dst.area AS destination_area,o.promised_at,o.amount,o.status
FROM orders o JOIN customers c ON c.id=o.customer_id JOIN platforms p ON p.id=o.platform_id
JOIN locations src ON src.id=o.pickup_location_id JOIN locations dst ON dst.id=o.destination_location_id;
