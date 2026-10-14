-- Indexes included in schema.sql for fast queue, location and rider lookups.
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_destination_time ON orders(destination_location_id,promised_at);
CREATE INDEX IF NOT EXISTS idx_batches_status ON delivery_batches(status);
CREATE INDEX IF NOT EXISTS idx_customers_location ON customers(location_id);
CREATE INDEX IF NOT EXISTS idx_riders_status ON riders(status);
CREATE INDEX IF NOT EXISTS idx_opportunities_status ON pooling_opportunities(status);
