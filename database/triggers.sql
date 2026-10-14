-- Run after schema.sql. These audit triggers are included in schema.sql already.
CREATE TRIGGER IF NOT EXISTS trg_order_status_history AFTER UPDATE OF status ON orders
WHEN OLD.status <> NEW.status BEGIN
  INSERT INTO order_status_history(order_id,old_status,new_status,note)
  VALUES(NEW.id,OLD.status,NEW.status,'Status changed by the application');
END;
CREATE TRIGGER IF NOT EXISTS trg_new_order_status_history AFTER INSERT ON orders BEGIN
  INSERT INTO order_status_history(order_id,old_status,new_status,note)
  VALUES(NEW.id,NULL,NEW.status,'Order created');
END;
