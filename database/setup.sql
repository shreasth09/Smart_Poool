-- Combined setup file for a fresh SQLite database.
-- Runtime application auto-runs this schema and seeds sample rows in server/src/db.js.
-- For a manual SQLite setup, execute schema.sql first, then seed.sql.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS platforms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL DEFAULT '#64748b',
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS locations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  area TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(name, area)
);
CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT NOT NULL,
  location_id INTEGER REFERENCES locations(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS riders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('Bike','Scooter','Cycle','EV')),
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available','on_delivery','offline')),
  rating REAL NOT NULL DEFAULT 4.5 CHECK (rating >= 0 AND rating <= 5),
  location_id INTEGER REFERENCES locations(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS rider_platforms (
  rider_id INTEGER NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
  platform_id INTEGER NOT NULL REFERENCES platforms(id) ON DELETE CASCADE,
  PRIMARY KEY(rider_id, platform_id)
);
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL UNIQUE,
  customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  platform_id INTEGER NOT NULL REFERENCES platforms(id) ON DELETE RESTRICT,
  pickup_location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  destination_location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  order_time TEXT NOT NULL,
  promised_at TEXT NOT NULL,
  amount REAL NOT NULL CHECK (amount >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','pooled','assigned','picked_up','delivered','cancelled')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS delivery_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_code TEXT NOT NULL UNIQUE,
  rider_id INTEGER REFERENCES riders(id) ON DELETE SET NULL,
  destination_location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','picked_up','delivered','cancelled')),
  total_orders INTEGER NOT NULL DEFAULT 0,
  estimated_distance_km REAL NOT NULL DEFAULT 0,
  estimated_savings_percent REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TEXT
);
CREATE TABLE IF NOT EXISTS batch_orders (
  batch_id INTEGER NOT NULL REFERENCES delivery_batches(id) ON DELETE CASCADE,
  order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY(batch_id, order_id)
);
CREATE TABLE IF NOT EXISTS pooling_opportunities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  opportunity_code TEXT NOT NULL UNIQUE,
  destination_location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
  order_ids TEXT NOT NULL,
  order_count INTEGER NOT NULL,
  time_window TEXT NOT NULL,
  estimated_savings_percent REAL NOT NULL DEFAULT 25,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','dismissed')),
  batch_id INTEGER REFERENCES delivery_batches(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS order_status_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  changed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note TEXT
);

CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_destination_time ON orders(destination_location_id, promised_at);
CREATE INDEX IF NOT EXISTS idx_batches_status ON delivery_batches(status);
CREATE INDEX IF NOT EXISTS idx_customers_location ON customers(location_id);
CREATE INDEX IF NOT EXISTS idx_riders_status ON riders(status);
CREATE INDEX IF NOT EXISTS idx_opportunities_status ON pooling_opportunities(status);

CREATE VIEW IF NOT EXISTS v_active_batches AS
SELECT b.id, b.batch_code, b.status, b.total_orders, b.estimated_distance_km,
       b.estimated_savings_percent, b.created_at, r.name AS rider_name,
       l.name AS destination, l.area AS destination_area
FROM delivery_batches b
LEFT JOIN riders r ON r.id = b.rider_id
JOIN locations l ON l.id = b.destination_location_id
WHERE b.status IN ('active','picked_up');

CREATE VIEW IF NOT EXISTS v_order_summary AS
SELECT o.id, o.order_code, c.name AS customer_name, p.name AS platform_name,
       src.name AS pickup_location, dst.name AS destination_location,
       dst.area AS destination_area, o.promised_at, o.amount, o.status
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN platforms p ON p.id = o.platform_id
JOIN locations src ON src.id = o.pickup_location_id
JOIN locations dst ON dst.id = o.destination_location_id;

CREATE TRIGGER IF NOT EXISTS trg_order_status_history
AFTER UPDATE OF status ON orders
WHEN OLD.status <> NEW.status
BEGIN
  INSERT INTO order_status_history(order_id, old_status, new_status, note)
  VALUES (NEW.id, OLD.status, NEW.status, 'Status changed by the application');
END;

CREATE TRIGGER IF NOT EXISTS trg_new_order_status_history
AFTER INSERT ON orders
BEGIN
  INSERT INTO order_status_history(order_id, old_status, new_status, note)
  VALUES (NEW.id, NULL, NEW.status, 'Order created');
END;


-- BEGIN SAMPLE DATA (same data set as seed.sql)
-- Smart Delivery Pooling System sample data (SQLite). Run after schema.sql on a fresh database.

PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

INSERT INTO platforms (name,code,color) VALUES
  ('Zomato', 'ZOM', '#ef4444'),
  ('Swiggy', 'SWG', '#f97316'),
  ('Blinkit', 'BLK', '#eab308'),
  ('Zepto', 'ZPT', '#a855f7'),
  ('Other', 'OTH', '#64748b');

INSERT INTO locations (name,area,address,latitude,longitude) VALUES
  ('Malviya Nagar Hub', 'Malviya Nagar', 'Malviya Nagar, Jaipur', 26.8545, 75.805),
  ('Vaishali Nagar Hub', 'Vaishali Nagar', 'Vaishali Nagar, Jaipur', 26.9124, 75.738),
  ('Mansarovar Hub', 'Mansarovar', 'Mansarovar, Jaipur', 26.854, 75.764),
  ('C-Scheme Hub', 'C-Scheme', 'C-Scheme, Jaipur', 26.912, 75.793),
  ('Jagatpura Hub', 'Jagatpura', 'Jagatpura, Jaipur', 26.839, 75.872),
  ('Raja Park Hub', 'Raja Park', 'Raja Park, Jaipur', 26.9, 75.823),
  ('Tonk Road Hub', 'Tonk Road', 'Tonk Road, Jaipur', 26.881, 75.803),
  ('Bani Park Hub', 'Bani Park', 'Bani Park, Jaipur', 26.934, 75.792),
  ('Vidyadhar Nagar Hub', 'Vidyadhar Nagar', 'Vidyadhar Nagar, Jaipur', 26.96, 75.779),
  ('Pratap Nagar Hub', 'Pratap Nagar', 'Pratap Nagar, Jaipur', 26.801, 75.832),
  ('Sodala Hub', 'Sodala', 'Sodala, Jaipur', 26.903, 75.76),
  ('Adarsh Nagar Hub', 'Adarsh Nagar', 'Adarsh Nagar, Jaipur', 26.891, 75.824);

INSERT INTO customers (name,email,phone,location_id) VALUES
  ('Aarav Sharma', 'customer1@example.com', '9810000000', 1),
  ('Aditi Verma', 'customer2@example.com', '9810000001', 2),
  ('Vihaan Gupta', 'customer3@example.com', '9810000002', 3),
  ('Ananya Mehta', 'customer4@example.com', '9810000003', 4),
  ('Reyansh Singh', 'customer5@example.com', '9810000004', 5),
  ('Ishita Joshi', 'customer6@example.com', '9810000005', 6),
  ('Kabir Agarwal', 'customer7@example.com', '9810000006', 7),
  ('Myra Jain', 'customer8@example.com', '9810000007', 8),
  ('Arjun Rathore', 'customer9@example.com', '9810000008', 9),
  ('Kiara Choudhary', 'customer10@example.com', '9810000009', 10),
  ('Advait Sharma', 'customer11@example.com', '9810000010', 11),
  ('Sara Verma', 'customer12@example.com', '9810000011', 12),
  ('Dhruv Gupta', 'customer13@example.com', '9810000012', 1),
  ('Riya Mehta', 'customer14@example.com', '9810000013', 2),
  ('Vivaan Singh', 'customer15@example.com', '9810000014', 3),
  ('Pari Joshi', 'customer16@example.com', '9810000015', 4),
  ('Ishaan Agarwal', 'customer17@example.com', '9810000016', 5),
  ('Tara Jain', 'customer18@example.com', '9810000017', 6),
  ('Krish Rathore', 'customer19@example.com', '9810000018', 7),
  ('Diya Choudhary', 'customer20@example.com', '9810000019', 8),
  ('Rudra Sharma', 'customer21@example.com', '9810000020', 9),
  ('Meera Verma', 'customer22@example.com', '9810000021', 10),
  ('Kiaan Gupta', 'customer23@example.com', '9810000022', 11),
  ('Aanya Mehta', 'customer24@example.com', '9810000023', 12),
  ('Dev Singh', 'customer25@example.com', '9810000024', 1);

INSERT INTO riders (name,phone,vehicle_type,status,rating,location_id) VALUES
  ('Rohit Kumar', '9710000000', 'Bike', 'available', 4.2, 1),
  ('Aman Sharma', '9710000001', 'Scooter', 'available', 4.3, 2),
  ('Sahil Verma', '9710000002', 'EV', 'available', 4.4, 3),
  ('Neha Singh', '9710000003', 'Bike', 'available', 4.5, 4),
  ('Manish Jain', '9710000004', 'Scooter', 'available', 4.6, 5),
  ('Karan Mehta', '9710000005', 'Cycle', 'available', 4.7, 6),
  ('Pooja Gupta', '9710000006', 'Bike', 'available', 4.8, 7),
  ('Deepak Yadav', '9710000007', 'Scooter', 'available', 4.9, 8),
  ('Ankit Joshi', '9710000008', 'EV', 'available', 4.2, 9),
  ('Simran Kaur', '9710000009', 'Bike', 'offline', 4.3, 10),
  ('Rahul Saini', '9710000010', 'Scooter', 'available', 4.4, 11),
  ('Tushar Raj', '9710000011', 'Cycle', 'available', 4.5, 12);

INSERT INTO rider_platforms (rider_id,platform_id) VALUES
  (1, 1),
  (1, 2),
  (1, 3),
  (1, 4),
  (1, 5),
  (2, 2),
  (2, 3),
  (3, 3),
  (3, 4),
  (4, 1),
  (4, 2),
  (4, 3),
  (4, 4),
  (4, 5),
  (5, 5),
  (5, 1),
  (6, 1),
  (6, 2),
  (7, 1),
  (7, 2),
  (7, 3),
  (7, 4),
  (7, 5),
  (8, 3),
  (8, 4),
  (9, 4),
  (9, 5),
  (10, 1),
  (10, 2),
  (10, 3),
  (10, 4),
  (10, 5),
  (11, 1),
  (11, 2),
  (12, 2),
  (12, 3);

INSERT INTO orders (order_code,customer_id,platform_id,pickup_location_id,destination_location_id,order_time,promised_at,amount,status) VALUES
  ('ORD-1001', 1, 1, 6, 1, datetime('now', '-10 minutes'), datetime('now', '+20 minutes'), 120, 'pending'),
  ('ORD-1002', 2, 2, 7, 1, datetime('now', '-11 minutes'), datetime('now', '+27 minutes'), 157, 'pending'),
  ('ORD-1003', 3, 3, 8, 1, datetime('now', '-12 minutes'), datetime('now', '+34 minutes'), 194, 'pending'),
  ('ORD-1004', 4, 4, 6, 1, datetime('now', '-13 minutes'), datetime('now', '+41 minutes'), 231, 'pending'),
  ('ORD-1005', 5, 5, 7, 1, datetime('now', '-14 minutes'), datetime('now', '+48 minutes'), 268, 'pending'),
  ('ORD-1006', 6, 1, 9, 2, datetime('now', '-15 minutes'), datetime('now', '+80 minutes'), 305, 'pending'),
  ('ORD-1007', 7, 2, 7, 2, datetime('now', '-16 minutes'), datetime('now', '+87 minutes'), 342, 'pending'),
  ('ORD-1008', 8, 3, 8, 2, datetime('now', '-17 minutes'), datetime('now', '+94 minutes'), 379, 'pending'),
  ('ORD-1009', 9, 4, 9, 2, datetime('now', '-18 minutes'), datetime('now', '+101 minutes'), 416, 'pending'),
  ('ORD-1010', 10, 5, 7, 2, datetime('now', '-19 minutes'), datetime('now', '+108 minutes'), 453, 'pending'),
  ('ORD-1011', 11, 1, 9, 3, datetime('now', '-20 minutes'), datetime('now', '+140 minutes'), 490, 'pending'),
  ('ORD-1012', 12, 2, 10, 3, datetime('now', '-21 minutes'), datetime('now', '+147 minutes'), 527, 'pending'),
  ('ORD-1013', 13, 3, 8, 3, datetime('now', '-22 minutes'), datetime('now', '+154 minutes'), 564, 'pending'),
  ('ORD-1014', 14, 4, 9, 3, datetime('now', '-23 minutes'), datetime('now', '+161 minutes'), 601, 'pending'),
  ('ORD-1015', 15, 5, 10, 3, datetime('now', '-24 minutes'), datetime('now', '+168 minutes'), 638, 'pending'),
  ('ORD-1016', 16, 1, 9, 4, datetime('now', '-25 minutes'), datetime('now', '+200 minutes'), 675, 'pending'),
  ('ORD-1017', 17, 2, 10, 4, datetime('now', '-26 minutes'), datetime('now', '+207 minutes'), 712, 'pending'),
  ('ORD-1018', 18, 3, 11, 4, datetime('now', '-27 minutes'), datetime('now', '+214 minutes'), 749, 'pending'),
  ('ORD-1019', 19, 4, 9, 4, datetime('now', '-28 minutes'), datetime('now', '+221 minutes'), 786, 'pending'),
  ('ORD-1020', 20, 5, 10, 4, datetime('now', '-29 minutes'), datetime('now', '+228 minutes'), 823, 'pending'),
  ('ORD-1021', 21, 1, 12, 5, datetime('now', '-30 minutes'), datetime('now', '+260 minutes'), 860, 'pending'),
  ('ORD-1022', 22, 2, 10, 5, datetime('now', '-31 minutes'), datetime('now', '+267 minutes'), 897, 'pending'),
  ('ORD-1023', 23, 3, 11, 5, datetime('now', '-32 minutes'), datetime('now', '+274 minutes'), 934, 'pending'),
  ('ORD-1024', 24, 4, 12, 5, datetime('now', '-33 minutes'), datetime('now', '+281 minutes'), 121, 'pending'),
  ('ORD-1025', 25, 5, 10, 5, datetime('now', '-34 minutes'), datetime('now', '+288 minutes'), 158, 'pending'),
  ('ORD-1026', 1, 1, 7, 1, datetime('now', '-35 minutes'), datetime('now', '+320 minutes'), 195, 'pending'),
  ('ORD-1027', 2, 2, 8, 1, datetime('now', '-36 minutes'), datetime('now', '+327 minutes'), 232, 'pending'),
  ('ORD-1028', 3, 3, 6, 1, datetime('now', '-37 minutes'), datetime('now', '+334 minutes'), 269, 'pending'),
  ('ORD-1029', 4, 4, 11, 5, datetime('now', '-38 minutes'), datetime('now', '+84 minutes'), 306, 'pending'),
  ('ORD-1030', 5, 5, 1, 6, datetime('now', '-39 minutes'), datetime('now', '+87 minutes'), 343, 'pending'),
  ('ORD-1031', 6, 1, 12, 7, datetime('now', '-40 minutes'), datetime('now', '+90 minutes'), 380, 'pending'),
  ('ORD-1032', 7, 2, 2, 8, datetime('now', '-41 minutes'), datetime('now', '+93 minutes'), 417, 'pending'),
  ('ORD-1033', 8, 3, 4, 9, datetime('now', '-42 minutes'), datetime('now', '+96 minutes'), 454, 'pending'),
  ('ORD-1034', 9, 4, 3, 10, datetime('now', '-43 minutes'), datetime('now', '+99 minutes'), 491, 'pending'),
  ('ORD-1035', 10, 5, 5, 11, datetime('now', '-44 minutes'), datetime('now', '+102 minutes'), 528, 'pending'),
  ('ORD-1036', 11, 1, 7, 12, datetime('now', '-45 minutes'), datetime('now', '+105 minutes'), 565, 'pending'),
  ('ORD-1037', 12, 2, 6, 1, datetime('now', '-46 minutes'), datetime('now', '+108 minutes'), 602, 'pending'),
  ('ORD-1038', 13, 3, 8, 2, datetime('now', '-47 minutes'), datetime('now', '+111 minutes'), 639, 'assigned'),
  ('ORD-1039', 14, 4, 10, 3, datetime('now', '-48 minutes'), datetime('now', '+114 minutes'), 676, 'assigned'),
  ('ORD-1040', 15, 5, 9, 4, datetime('now', '-49 minutes'), datetime('now', '+117 minutes'), 713, 'assigned'),
  ('ORD-1041', 16, 1, 11, 5, datetime('now', '-50 minutes'), datetime('now', '+120 minutes'), 750, 'delivered'),
  ('ORD-1042', 17, 2, 1, 6, datetime('now', '-51 minutes'), datetime('now', '+123 minutes'), 787, 'assigned'),
  ('ORD-1043', 18, 3, 12, 7, datetime('now', '-52 minutes'), datetime('now', '+126 minutes'), 824, 'assigned'),
  ('ORD-1044', 19, 4, 2, 8, datetime('now', '-53 minutes'), datetime('now', '+129 minutes'), 861, 'assigned'),
  ('ORD-1045', 20, 5, 4, 9, datetime('now', '-54 minutes'), datetime('now', '+132 minutes'), 898, 'delivered'),
  ('ORD-1046', 21, 1, 3, 10, datetime('now', '-55 minutes'), datetime('now', '+135 minutes'), 935, 'assigned'),
  ('ORD-1047', 22, 2, 5, 11, datetime('now', '-56 minutes'), datetime('now', '+138 minutes'), 122, 'assigned'),
  ('ORD-1048', 23, 3, 7, 12, datetime('now', '-57 minutes'), datetime('now', '+141 minutes'), 159, 'assigned'),
  ('ORD-1049', 24, 4, 6, 1, datetime('now', '-58 minutes'), datetime('now', '+144 minutes'), 196, 'delivered'),
  ('ORD-1050', 25, 5, 8, 2, datetime('now', '-59 minutes'), datetime('now', '+147 minutes'), 233, 'assigned');

UPDATE orders SET status='delivered' WHERE id=39;

UPDATE orders SET status='delivered' WHERE id=40;

UPDATE orders SET status='delivered' WHERE id=41;

UPDATE orders SET status='delivered' WHERE id=42;

UPDATE orders SET status='delivered' WHERE id=43;

UPDATE orders SET status='delivered' WHERE id=44;

UPDATE orders SET status='delivered' WHERE id=45;

UPDATE orders SET status='delivered' WHERE id=46;

UPDATE orders SET status='delivered' WHERE id=47;

UPDATE orders SET status='delivered' WHERE id=48;

UPDATE orders SET status='delivered' WHERE id=49;

UPDATE orders SET status='delivered' WHERE id=50;

INSERT INTO delivery_batches (batch_code,rider_id,destination_location_id,status,total_orders,estimated_distance_km,estimated_savings_percent,created_at,completed_at) VALUES
  ('BAT-H1', 1, 1, 'delivered', 2, 2.40, 18, datetime('now', '-1440 minutes'), datetime('now', '-1400 minutes')),
  ('BAT-H2', 2, 2, 'delivered', 2, 3.05, 21, datetime('now', '-2880 minutes'), datetime('now', '-2800 minutes')),
  ('BAT-H3', 3, 3, 'delivered', 2, 3.70, 24, datetime('now', '-4320 minutes'), datetime('now', '-4200 minutes')),
  ('BAT-H4', 4, 4, 'delivered', 3, 4.35, 27, datetime('now', '-5760 minutes'), datetime('now', '-5600 minutes')),
  ('BAT-H5', 5, 5, 'delivered', 3, 5.00, 30, datetime('now', '-7200 minutes'), datetime('now', '-7000 minutes'));

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (1,39,1);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (1,40,2);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (2,41,1);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (2,42,2);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (3,43,1);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (3,44,2);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (4,45,1);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (4,46,2);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (4,47,3);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (5,48,1);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (5,49,2);

INSERT INTO batch_orders(batch_id,order_id,sequence_no) VALUES (5,50,3);

COMMIT;
