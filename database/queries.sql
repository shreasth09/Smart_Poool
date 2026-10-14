-- 30 representative SQL queries for the Smart Delivery Pooling System.
-- Run with SQLite 3.38+ (or the application's built-in node:sqlite).

-- Q01. Order detail across customer, platform and destination.
SELECT * FROM v_order_summary ORDER BY id DESC;

-- Q02. All orders waiting to be pooled.
SELECT order_code, customer_name, platform_name, destination_area, promised_at, amount
FROM v_order_summary WHERE status='pending' ORDER BY promised_at;

-- Q03. Count orders by current status.
SELECT status, COUNT(*) AS order_count FROM orders GROUP BY status ORDER BY order_count DESC;

-- Q04. Order volume by platform.
SELECT p.name AS platform, COUNT(o.id) AS orders
FROM platforms p LEFT JOIN orders o ON o.platform_id=p.id GROUP BY p.id ORDER BY orders DESC;

-- Q05. Platform delivery completion percentages.
SELECT p.name AS platform, COUNT(o.id) AS total_orders,
       SUM(CASE WHEN o.status='delivered' THEN 1 ELSE 0 END) AS delivered_orders,
       ROUND(100.0*SUM(CASE WHEN o.status='delivered' THEN 1 ELSE 0 END)/NULLIF(COUNT(o.id),0),1) AS completion_percent
FROM platforms p LEFT JOIN orders o ON o.platform_id=p.id GROUP BY p.id;

-- Q06. Customers with the highest number of orders.
SELECT c.id,c.name,COUNT(o.id) AS order_count FROM customers c
LEFT JOIN orders o ON o.customer_id=c.id GROUP BY c.id ORDER BY order_count DESC,c.name LIMIT 10;

-- Q07. Customers by home area.
SELECT l.area,COUNT(c.id) AS customer_count FROM locations l
LEFT JOIN customers c ON c.location_id=l.id GROUP BY l.id ORDER BY customer_count DESC;

-- Q08. Available riders with their home zones.
SELECT r.id,r.name,r.vehicle_type,r.rating,l.area AS zone FROM riders r
LEFT JOIN locations l ON l.id=r.location_id WHERE r.status='available' ORDER BY r.rating DESC;

-- Q09. Platforms each rider is registered to support.
SELECT r.name AS rider,GROUP_CONCAT(p.name,', ') AS supported_platforms
FROM riders r LEFT JOIN rider_platforms rp ON rp.rider_id=r.id
LEFT JOIN platforms p ON p.id=rp.platform_id GROUP BY r.id ORDER BY r.name;

-- Q10. Current rider workload.
SELECT r.name,r.status,COUNT(DISTINCT b.id) AS active_batches,
       COALESCE(SUM(CASE WHEN b.status IN ('active','picked_up') THEN b.total_orders ELSE 0 END),0) AS active_orders
FROM riders r LEFT JOIN delivery_batches b ON b.rider_id=r.id GROUP BY r.id ORDER BY active_orders DESC;

-- Q11. Highest-demand destination zones.
SELECT l.area,COUNT(o.id) AS total_orders,
       SUM(CASE WHEN o.status='pending' THEN 1 ELSE 0 END) AS pending_orders
FROM locations l LEFT JOIN orders o ON o.destination_location_id=l.id
GROUP BY l.id ORDER BY pending_orders DESC,total_orders DESC;

-- Q12. Average and total order value by platform.
SELECT p.name,COUNT(o.id) AS orders,ROUND(AVG(o.amount),2) AS average_order_value,
       ROUND(SUM(o.amount),2) AS gross_order_value
FROM platforms p LEFT JOIN orders o ON o.platform_id=p.id GROUP BY p.id ORDER BY gross_order_value DESC;

-- Q13. High-value orders (₹500+).
SELECT order_code,customer_name,platform_name,amount,status FROM v_order_summary
WHERE amount>=500 ORDER BY amount DESC;

-- Q14. Orders due in the next 60 minutes.
SELECT order_code,customer_name,destination_area,promised_at FROM v_order_summary
WHERE status='pending' AND datetime(promised_at)<=datetime('now','+60 minutes')
ORDER BY promised_at;

-- Q15. Active and picked-up delivery batches.
SELECT * FROM v_active_batches ORDER BY created_at DESC;

-- Q16. Completed batches with savings and order count.
SELECT batch_code,total_orders,estimated_distance_km,estimated_savings_percent,completed_at
FROM delivery_batches WHERE status='delivered' ORDER BY completed_at DESC;

-- Q17. Orders assigned to each batch.
SELECT b.batch_code,o.order_code,c.name AS customer,p.name AS platform,bo.sequence_no
FROM delivery_batches b JOIN batch_orders bo ON bo.batch_id=b.id
JOIN orders o ON o.id=bo.order_id JOIN customers c ON c.id=o.customer_id
JOIN platforms p ON p.id=o.platform_id ORDER BY b.id,bo.sequence_no;

-- Q18. Current open pooling opportunities.
SELECT po.opportunity_code,l.area,po.order_count,po.time_window,po.estimated_savings_percent,po.status
FROM pooling_opportunities po JOIN locations l ON l.id=po.destination_location_id
WHERE po.status='open' ORDER BY po.estimated_savings_percent DESC;

-- Q19. Number of opportunities by state.
SELECT status,COUNT(*) AS opportunity_count FROM pooling_opportunities GROUP BY status;

-- Q20. Order status history for audit.
SELECT h.changed_at,o.order_code,h.old_status,h.new_status,h.note
FROM order_status_history h JOIN orders o ON o.id=h.order_id ORDER BY h.changed_at DESC LIMIT 30;

-- Q21. All active platforms.
SELECT id,name,code,color FROM platforms WHERE is_active=1 ORDER BY name;

-- Q22. Order volume by promised delivery hour.
SELECT strftime('%H',promised_at) AS delivery_hour,COUNT(*) AS order_count
FROM orders GROUP BY delivery_hour ORDER BY delivery_hour;

-- Q23. Rider ratings by vehicle type.
SELECT vehicle_type,COUNT(*) AS riders,ROUND(AVG(rating),2) AS average_rating
FROM riders GROUP BY vehicle_type ORDER BY average_rating DESC;

-- Q24. Average batch size and average estimated savings.
SELECT COUNT(*) AS total_batches,ROUND(AVG(total_orders),2) AS avg_orders_per_batch,
       ROUND(AVG(estimated_savings_percent),2) AS avg_estimated_savings
FROM delivery_batches;

-- Q25. Pending orders not assigned to any batch.
SELECT o.order_code,c.name AS customer,l.area AS destination,o.promised_at
FROM orders o JOIN customers c ON c.id=o.customer_id JOIN locations l ON l.id=o.destination_location_id
LEFT JOIN batch_orders bo ON bo.order_id=o.id
WHERE o.status='pending' AND bo.order_id IS NULL ORDER BY o.promised_at;

-- Q26. Supported-platform count per rider.
SELECT r.name,COUNT(rp.platform_id) AS platform_count
FROM riders r LEFT JOIN rider_platforms rp ON rp.rider_id=r.id
GROUP BY r.id ORDER BY platform_count DESC,r.name;

-- Q27. Orders by destination and platform.
SELECT l.area,p.name AS platform,COUNT(o.id) AS order_count
FROM orders o JOIN locations l ON l.id=o.destination_location_id JOIN platforms p ON p.id=o.platform_id
GROUP BY l.id,p.id ORDER BY l.area,p.name;

-- Q28. Successful delivered-order value by customer.
SELECT c.name,COUNT(o.id) AS delivered_orders,ROUND(SUM(o.amount),2) AS delivered_value
FROM customers c JOIN orders o ON o.customer_id=c.id
WHERE o.status='delivered' GROUP BY c.id ORDER BY delivered_value DESC LIMIT 10;

-- Q29. Distance savings estimate by destination zone.
SELECT l.area,COUNT(b.id) AS batch_count,ROUND(AVG(b.estimated_distance_km),2) AS avg_km,
       ROUND(AVG(b.estimated_savings_percent),1) AS avg_savings_percent
FROM locations l LEFT JOIN delivery_batches b ON b.destination_location_id=l.id
GROUP BY l.id ORDER BY batch_count DESC;

-- Q30. Full summary for the dashboard KPI cards.
SELECT
 (SELECT COUNT(*) FROM orders) AS total_orders,
 (SELECT COUNT(*) FROM orders WHERE status='pending') AS pending_orders,
 (SELECT COUNT(*) FROM orders WHERE status='delivered') AS delivered_orders,
 (SELECT COUNT(*) FROM riders WHERE status='available') AS available_riders,
 (SELECT COUNT(*) FROM delivery_batches WHERE status IN ('active','picked_up')) AS active_batches,
 (SELECT COUNT(*) FROM pooling_opportunities WHERE status='open') AS open_opportunities;
