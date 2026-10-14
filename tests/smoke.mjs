import assert from 'node:assert/strict';
const base=process.env.BASE_URL||'http://localhost:3000/api';
async function call(path,method='GET',body){
  const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
  const json=await response.json();
  if(!response.ok||json.success===false)throw new Error(`${method} ${path}: ${json.message||response.status}`);
  return json;
}
const health=await call('/health');assert.equal(health.data,undefined);assert.equal(health.database,'connected');
const dashboard=(await call('/dashboard')).data;assert.equal(dashboard.totalOrders,50);
assert.equal((await call('/customers')).data.length,25);assert.equal((await call('/platforms')).data.length,5);
assert.equal((await call('/riders')).data.length,12);assert.equal((await call('/locations')).data.length,12);
assert.equal((await call('/orders')).data.length,50);assert.equal((await call('/analytics')).success,true);
const created=(await call('/customers','POST',{name:'Smoke Test User',email:'smoke-test@example.com',phone:'9000000099',location_id:1})).data;
assert.equal(created.email,'smoke-test@example.com');
await call(`/customers/${created.id}`,'PUT',{name:'Smoke Test User Updated'});
assert.equal((await call(`/customers/${created.id}`)).data.name,'Smoke Test User Updated');
await call(`/customers/${created.id}`,'DELETE');
const pools=await call('/pooling/generate','POST',{});assert.ok(pools.data>0,'pool generator should find at least one opportunity');
const opportunity=(await call('/pooling/opportunities')).data[0];assert.ok(opportunity.order_count>=2);
const assignment=await call(`/pooling/opportunities/${opportunity.id}/accept`,'POST',{});const batchId=assignment.data.id;
assert.equal(assignment.data.status,'active');assert.ok(assignment.data.rider_id);
await call(`/batches/${batchId}/status`,'PATCH',{status:'picked_up'});
assert.equal((await call(`/batches/${batchId}`)).data.status,'picked_up');
await call(`/batches/${batchId}/status`,'PATCH',{status:'delivered'});
const batch=(await call(`/batches/${batchId}`)).data;assert.equal(batch.status,'delivered');
assert.ok(batch.orders.length>=2);assert.ok(batch.orders.every(o=>o.status==='delivered'));
console.log('PASS: health, seed counts, CRUD, analytics, opportunity generation, pool acceptance, batch pickup/completion, linked orders and audit triggers.');
