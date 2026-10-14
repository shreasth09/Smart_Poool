import { Router } from './router.js';
import db from './db.js';
import { randomUUID } from 'node:crypto';

const router = Router();
const list = (sql, params = []) => db.prepare(sql).all(...params);
const one = (sql, params = []) => db.prepare(sql).get(...params);
const run = (sql, params = []) => db.prepare(sql).run(...params);
const sendError = (res, message, status = 400) => res.status(status).json({ success: false, message });

router.get('/health', (_req,res) => res.json({ success:true, service:'Smart Delivery Pooling API', database:'connected', timestamp:new Date().toISOString() }));

router.get('/dashboard', (_req,res) => {
  const totals = one(`SELECT
    (SELECT COUNT(*) FROM orders) AS totalOrders,
    (SELECT COUNT(*) FROM orders WHERE status='pending') AS pendingOrders,
    (SELECT COUNT(*) FROM orders WHERE status='delivered') AS deliveredOrders,
    (SELECT COUNT(*) FROM riders WHERE status='available') AS availableRiders,
    (SELECT COUNT(*) FROM delivery_batches WHERE status IN ('active','picked_up')) AS activeBatches,
    (SELECT COUNT(*) FROM pooling_opportunities WHERE status='open') AS openOpportunities,
    (SELECT COALESCE(SUM(amount),0) FROM orders WHERE status='delivered') AS deliveredValue,
    (SELECT COALESCE(AVG(total_orders),0) FROM delivery_batches WHERE status='delivered') AS avgBatchSize`);
  const orderMix = list(`SELECT status, COUNT(*) AS value FROM orders GROUP BY status`);
  const platformMix = list(`SELECT p.name, COUNT(o.id) AS orders FROM platforms p LEFT JOIN orders o ON o.platform_id=p.id GROUP BY p.id ORDER BY orders DESC`);
  const trend = list(`SELECT date(created_at) AS day, COUNT(*) AS orders FROM orders GROUP BY date(created_at) ORDER BY day DESC LIMIT 7`).reverse();
  res.json({success:true,data:{...totals,orderMix,platformMix,trend}});
});

router.get('/analytics', (_req,res) => {
  const platformPerformance = list(`SELECT p.name AS platform, COUNT(o.id) AS orders, ROUND(COALESCE(SUM(o.amount),0),2) AS gross_value,
    SUM(CASE WHEN o.status='delivered' THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN o.status='pending' THEN 1 ELSE 0 END) AS pending
    FROM platforms p LEFT JOIN orders o ON o.platform_id=p.id GROUP BY p.id ORDER BY orders DESC`);
  const batchStats = one(`SELECT COUNT(*) AS totalBatches, COALESCE(ROUND(AVG(total_orders),1),0) AS averageOrders,
    COALESCE(ROUND(AVG(estimated_savings_percent),1),0) AS averageSavings,
    COALESCE(SUM(total_orders),0) AS pooledOrders FROM delivery_batches`);
  const statusDistribution = list(`SELECT status,COUNT(*) AS count FROM orders GROUP BY status`);
  const topAreas = list(`SELECT l.area, COUNT(o.id) AS orders FROM locations l LEFT JOIN orders o ON o.destination_location_id=l.id GROUP BY l.id ORDER BY orders DESC LIMIT 6`);
  res.json({success:true,data:{platformPerformance,batchStats,statusDistribution,topAreas}});
});

const resources = {
  customers: {
    table:'customers', fields:['name','email','phone','location_id'], required:['name','email','phone'],
    select:`SELECT c.*, l.name AS location_name, l.area AS location_area FROM customers c LEFT JOIN locations l ON l.id=c.location_id`,
    order:'c.id DESC', aliases:'customers c',
    normalize:b=>({...b, location_id:b.location_id ? Number(b.location_id) : null})
  },
  platforms: {table:'platforms', fields:['name','code','color','is_active'], required:['name','code'], select:'SELECT * FROM platforms', order:'id DESC', normalize:b=>({...b,is_active:b.is_active===false||b.is_active===0?0:1})},
  riders: {
    table:'riders', fields:['name','phone','vehicle_type','status','rating','location_id'], required:['name','phone','vehicle_type'],
    select:`SELECT r.*, l.name AS location_name, l.area AS location_area,
      (SELECT GROUP_CONCAT(p.name, ', ') FROM rider_platforms rp JOIN platforms p ON p.id=rp.platform_id WHERE rp.rider_id=r.id) AS platforms
      FROM riders r LEFT JOIN locations l ON l.id=r.location_id`, order:'r.id DESC',
    normalize:b=>({...b,rating:Number(b.rating??4.5),location_id:b.location_id?Number(b.location_id):null})
  },
  locations: {table:'locations',fields:['name','area','address','latitude','longitude'],required:['name','area','address'],select:'SELECT * FROM locations',order:'id DESC',normalize:b=>({...b,latitude:Number(b.latitude??26.9),longitude:Number(b.longitude??75.8)})},
  orders: {
    table:'orders',fields:['customer_id','platform_id','pickup_location_id','destination_location_id','promised_at','amount','status'],required:['customer_id','platform_id','pickup_location_id','destination_location_id','promised_at','amount'],
    select:`SELECT o.*, c.name AS customer_name, p.name AS platform_name, src.name AS pickup_name,
      dst.name AS destination_name, dst.area AS destination_area
      FROM orders o JOIN customers c ON c.id=o.customer_id JOIN platforms p ON p.id=o.platform_id
      JOIN locations src ON src.id=o.pickup_location_id JOIN locations dst ON dst.id=o.destination_location_id`,order:'o.id DESC',
    normalize:b=>({customer_id:Number(b.customer_id),platform_id:Number(b.platform_id),pickup_location_id:Number(b.pickup_location_id),destination_location_id:Number(b.destination_location_id),promised_at:b.promised_at,amount:Number(b.amount),status:b.status||'pending'})
  }
};

function getResourceRows(key) {
  const r=resources[key];
  if (!r) return null;
  return list(`${r.select} ORDER BY ${r.order}`);
}
for (const key of Object.keys(resources)) {
  router.get(`/${key}`, (_req,res)=>res.json({success:true,data:getResourceRows(key)}));
  router.get(`/${key}/:id`, (req,res)=>{
    const r=resources[key];
    const rows=list(`${r.select} WHERE ${key==='customers'?'c.id':key==='riders'?'r.id':key==='orders'?'o.id':'id'}=?`,[Number(req.params.id)]);
    if(!rows.length) return sendError(res, `${key.slice(0,-1)} not found`,404);
    res.json({success:true,data:rows[0]});
  });
  router.post(`/${key}`, (req,res)=>{
    const r=resources[key]; const body=r.normalize ? r.normalize(req.body||{}) : (req.body||{});
    const missing=r.required.filter(f=>body[f]===undefined||body[f]===null||String(body[f]).trim()==='');
    if(missing.length) return sendError(res,`Please provide: ${missing.join(', ')}`);
    try {
      const fields=r.fields.filter(f=>body[f]!==undefined);
      const vals=fields.map(f=>body[f]);
      let inserted;
      if(key==='orders') {
        const code=`ORD-${Date.now().toString().slice(-7)}-${Math.floor(Math.random()*90+10)}`;
        const fieldsWithCode=['order_code',...fields,'order_time'];
        const valsWithCode=[code,...vals,new Date().toISOString()];
        const stmt=run(`INSERT INTO orders (${fieldsWithCode.join(',')}) VALUES (${fieldsWithCode.map(()=>'?').join(',')})`,valsWithCode);
        inserted=stmt.lastInsertRowid;
      } else {
        const stmt=run(`INSERT INTO ${r.table} (${fields.join(',')}) VALUES (${fields.map(()=>'?').join(',')})`,vals);
        inserted=stmt.lastInsertRowid;
      }
      const row=one(`SELECT * FROM ${r.table} WHERE id=?`,[inserted]);
      res.status(201).json({success:true,message:'Record created',data:row});
    } catch(e) { return sendError(res, friendlyDbError(e)); }
  });
  router.put(`/${key}/:id`, (req,res)=>{
    const r=resources[key]; const id=Number(req.params.id); const body=r.normalize?r.normalize(req.body||{}):(req.body||{});
    if(!one(`SELECT id FROM ${r.table} WHERE id=?`,[id])) return sendError(res,'Record not found',404);
    const fields=r.fields.filter(f=>body[f]!==undefined);
    if(!fields.length) return sendError(res,'No editable fields supplied');
    try {
      run(`UPDATE ${r.table} SET ${fields.map(f=>`${f}=?`).join(',')} WHERE id=?`,[...fields.map(f=>body[f]),id]);
      res.json({success:true,message:'Record updated',data:one(`SELECT * FROM ${r.table} WHERE id=?`,[id])});
    } catch(e) { return sendError(res,friendlyDbError(e)); }
  });
  router.delete(`/${key}/:id`,(req,res)=>{
    try {
      const id=Number(req.params.id); const r=resources[key];
      const stmt=run(`DELETE FROM ${r.table} WHERE id=?`,[id]);
      if(!stmt.changes) return sendError(res,'Record not found',404);
      res.json({success:true,message:'Record deleted'});
    } catch(e) { return sendError(res,`This record is linked to other data and cannot be deleted yet. ${friendlyDbError(e)}`,409); }
  });
}

function friendlyDbError(e) {
  if(e.message.includes('UNIQUE constraint failed: customers.email')) return 'This email is already registered.';
  if(e.message.includes('UNIQUE constraint failed: riders.phone')) return 'This phone number is already registered.';
  if(e.message.includes('UNIQUE constraint failed: platforms.name')||e.message.includes('UNIQUE constraint failed: platforms.code')) return 'Platform name and code must be unique.';
  if(e.message.includes('FOREIGN KEY constraint failed')) return 'One of the selected linked records does not exist or is still in use.';
  if(e.message.includes('CHECK constraint failed')) return 'One of the supplied values is invalid.';
  return e.message;
}

router.get('/batches',(_req,res)=>res.json({success:true,data:list(`SELECT b.*, r.name AS rider_name, l.name AS destination_name, l.area AS destination_area,
  (SELECT GROUP_CONCAT(o.order_code, ', ') FROM batch_orders bo JOIN orders o ON o.id=bo.order_id WHERE bo.batch_id=b.id) AS order_codes
  FROM delivery_batches b LEFT JOIN riders r ON r.id=b.rider_id JOIN locations l ON l.id=b.destination_location_id ORDER BY b.id DESC`)}));
router.get('/batches/:id', (req,res)=>{
  const b=one(`SELECT b.*,r.name AS rider_name,l.name AS destination_name FROM delivery_batches b LEFT JOIN riders r ON r.id=b.rider_id JOIN locations l ON l.id=b.destination_location_id WHERE b.id=?`,[Number(req.params.id)]);
  if(!b)return sendError(res,'Batch not found',404);
  b.orders=list(`SELECT o.*,c.name AS customer_name,p.name AS platform_name FROM batch_orders bo JOIN orders o ON o.id=bo.order_id JOIN customers c ON c.id=o.customer_id JOIN platforms p ON p.id=o.platform_id WHERE bo.batch_id=? ORDER BY bo.sequence_no`,[b.id]);
  res.json({success:true,data:b});
});
router.patch('/batches/:id/status',(req,res)=>{
  const {status}=req.body||{};
  if(!['active','picked_up','delivered','cancelled'].includes(status)) return sendError(res,'Invalid batch status');
  const batch=one('SELECT * FROM delivery_batches WHERE id=?',[Number(req.params.id)]); if(!batch)return sendError(res,'Batch not found',404);
  const tx=db.transaction(()=>{
    run('UPDATE delivery_batches SET status=?, completed_at=? WHERE id=?',[status,status==='delivered'?new Date().toISOString():null,batch.id]);
    if(status==='delivered') {
      run(`UPDATE orders SET status='delivered' WHERE id IN (SELECT order_id FROM batch_orders WHERE batch_id=?)`,[batch.id]);
      if(batch.rider_id) run(`UPDATE riders SET status='available' WHERE id=?`,[batch.rider_id]);
    } else if(status==='picked_up') run(`UPDATE orders SET status='picked_up' WHERE id IN (SELECT order_id FROM batch_orders WHERE batch_id=?)`,[batch.id]);
    else if(status==='cancelled') {
      run(`UPDATE orders SET status='pending' WHERE id IN (SELECT order_id FROM batch_orders WHERE batch_id=?) AND status IN ('pooled','assigned','picked_up')`,[batch.id]);
      if(batch.rider_id) run(`UPDATE riders SET status='available' WHERE id=?`,[batch.rider_id]);
    }
  }); tx(); res.json({success:true,message:`Batch marked ${status}`,data:one('SELECT * FROM delivery_batches WHERE id=?',[batch.id])});
});

router.get('/pooling/opportunities',(_req,res)=>res.json({success:true,data:list(`SELECT po.*,l.name AS destination_name,l.area AS destination_area,
  (SELECT GROUP_CONCAT(o.order_code, ', ') FROM json_each(po.order_ids) j JOIN orders o ON o.id=CAST(j.value AS INTEGER)) AS order_codes
  FROM pooling_opportunities po JOIN locations l ON l.id=po.destination_location_id WHERE po.status='open' ORDER BY po.created_at DESC`)}));

router.post('/pooling/generate',(_req,res)=>{
  const pending=list(`SELECT o.*, l.area AS destination_area FROM orders o JOIN locations l ON l.id=o.destination_location_id
    WHERE o.status='pending' ORDER BY o.destination_location_id,o.promised_at`);
  const groups=[]; const used=new Set(); const maxMinutes=75;
  for(const first of pending){
    if(used.has(first.id)) continue;
    const group=[first]; used.add(first.id);
    for(const candidate of pending){
      if(used.has(candidate.id)||candidate.destination_location_id!==first.destination_location_id) continue;
      const delta=Math.abs(new Date(candidate.promised_at).getTime()-new Date(first.promised_at).getTime())/60000;
      if(delta<=maxMinutes && group.length<4){ group.push(candidate); used.add(candidate.id); }
    }
    if(group.length>=2) groups.push(group);
    else group.forEach(o=>used.delete(o.id));
  }
  const tx=db.transaction(()=>{
    run(`DELETE FROM pooling_opportunities WHERE status='open'`);
    const ins=db.prepare(`INSERT INTO pooling_opportunities (opportunity_code,destination_location_id,order_ids,order_count,time_window,estimated_savings_percent,status) VALUES (?,?,?,?,?,?, 'open')`);
    groups.forEach((g,i)=>{
      const ids=g.map(o=>o.id); const dates=g.map(o=>new Date(o.promised_at).getTime());
      const window=`${new Date(Math.min(...dates)).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'})}–${new Date(Math.max(...dates)).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'})}`;
      ins.run(`POOL-${Date.now().toString().slice(-5)}-${i+1}`,g[0].destination_location_id,JSON.stringify(ids),g.length,window,Math.min(42,18+g.length*5));
    });
  }); tx();
  res.json({success:true,message:`Generated ${groups.length} pooling opportunity group(s).`,data:groups.length});
});

router.post('/pooling/opportunities/:id/accept',(req,res)=>{
  const opportunity=one(`SELECT * FROM pooling_opportunities WHERE id=? AND status='open'`,[Number(req.params.id)]);
  if(!opportunity)return sendError(res,'Opportunity not found or already handled.',404);
  const orderIds=JSON.parse(opportunity.order_ids);
  const orders=list(`SELECT * FROM orders WHERE id IN (${orderIds.map(()=>'?').join(',')})`,orderIds);
  if(orders.length<2||orders.some(o=>o.status!=='pending'))return sendError(res,'Orders are no longer available for pooling. Generate opportunities again.',409);
  const platforms=[...new Set(orders.map(o=>o.platform_id))];
  const riders=list(`SELECT r.* FROM riders r WHERE r.status='available' AND NOT EXISTS (
    SELECT 1 FROM (SELECT ? AS platform_id ${platforms.slice(1).map(()=> 'UNION ALL SELECT ? AS platform_id').join(' ')}) required
    WHERE NOT EXISTS (SELECT 1 FROM rider_platforms rp WHERE rp.rider_id=r.id AND rp.platform_id=required.platform_id)
  ) ORDER BY r.rating DESC`,platforms);
  if(!riders.length)return sendError(res,'No available rider supports every platform in this pool. Try another opportunity. ',409);
  const rider=riders[0];
  const distance=Number((1.8+orders.length*0.65).toFixed(1));
  const tx=db.transaction(()=>{
    const batchCode=`BAT-${Date.now().toString().slice(-7)}`;
    const result=run(`INSERT INTO delivery_batches (batch_code,rider_id,destination_location_id,status,total_orders,estimated_distance_km,estimated_savings_percent) VALUES (?,?,?,'active',?,?,?)`,[batchCode,rider.id,opportunity.destination_location_id,orders.length,distance,opportunity.estimated_savings_percent]);
    const batchId=Number(result.lastInsertRowid);
    const add= db.prepare('INSERT INTO batch_orders (batch_id,order_id,sequence_no) VALUES (?,?,?)');
    orderIds.forEach((orderId,i)=>add.run(batchId,orderId,i+1));
    run(`UPDATE orders SET status='assigned' WHERE id IN (${orderIds.map(()=>'?').join(',')})`,orderIds);
    run(`UPDATE riders SET status='on_delivery' WHERE id=?`,[rider.id]);
    run(`UPDATE pooling_opportunities SET status='accepted',batch_id=? WHERE id=?`,[batchId,opportunity.id]);
    return one(`SELECT b.*,r.name AS rider_name,l.name AS destination_name FROM delivery_batches b JOIN riders r ON r.id=b.rider_id JOIN locations l ON l.id=b.destination_location_id WHERE b.id=?`,[batchId]);
  });
  try { res.json({success:true,message:'Opportunity accepted and batch assigned.',data:tx()}); }
  catch(e){res.status(500).json({success:false,message:e.message});}
});
router.post('/pooling/opportunities/:id/dismiss',(req,res)=>{
  const result=run(`UPDATE pooling_opportunities SET status='dismissed' WHERE id=? AND status='open'`,[Number(req.params.id)]);
  if(!result.changes)return sendError(res,'Opportunity not found or already handled.',404);
  res.json({success:true,message:'Opportunity dismissed.'});
});

router.get('/map/locations',(_req,res)=>res.json({success:true,data:list(`SELECT l.*, (SELECT COUNT(*) FROM orders o WHERE o.destination_location_id=l.id AND o.status='pending') AS pending_orders,
 (SELECT COUNT(*) FROM riders r WHERE r.location_id=l.id AND r.status='available') AS available_riders FROM locations l ORDER BY l.area`)}));
router.get('/lookup',(_req,res)=>res.json({success:true,data:{customers:list('SELECT id,name FROM customers ORDER BY name'),platforms:list('SELECT id,name FROM platforms WHERE is_active=1 ORDER BY name'),riders:list("SELECT id,name,status FROM riders ORDER BY name"),locations:list('SELECT id,name,area FROM locations ORDER BY area')}}));

export default router;
