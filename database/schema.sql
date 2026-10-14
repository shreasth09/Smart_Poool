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
