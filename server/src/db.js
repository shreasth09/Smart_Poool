import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../data');
fs.mkdirSync(dataDir, { recursive: true });
const db = new DatabaseSync(path.join(dataDir, 'pooling.db'));
db.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;');
const schema = fs.readFileSync(path.resolve(__dirname, '../database/schema.sql'), 'utf8');
db.exec(schema);
// Small transaction helper: native node:sqlite deliberately exposes statements, not a transaction wrapper.
db.transaction = (callback) => (...args) => {
  db.exec('BEGIN IMMEDIATE');
  try { const value = callback(...args); db.exec('COMMIT'); return value; }
  catch (error) { db.exec('ROLLBACK'); throw error; }
};

const count = (table) => db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get().n;
function seedDatabase() {
  if (count('platforms') > 0) return;
  const seed = db.transaction(() => {
    const addPlatform = db.prepare('INSERT INTO platforms (name,code,color) VALUES (?,?,?)');
    [['Zomato','ZOM','#ef4444'],['Swiggy','SWG','#f97316'],['Blinkit','BLK','#eab308'],['Zepto','ZPT','#a855f7'],['Other','OTH','#64748b']].forEach(p=>addPlatform.run(...p));
    const addLocation = db.prepare('INSERT INTO locations (name,area,address,latitude,longitude) VALUES (?,?,?,?,?)');
    const locData = [
      ['Malviya Nagar Hub','Malviya Nagar','Malviya Nagar, Jaipur',26.8545,75.8050],['Vaishali Nagar Hub','Vaishali Nagar','Vaishali Nagar, Jaipur',26.9124,75.7380],['Mansarovar Hub','Mansarovar','Mansarovar, Jaipur',26.8540,75.7640],['C-Scheme Hub','C-Scheme','C-Scheme, Jaipur',26.9120,75.7930],['Jagatpura Hub','Jagatpura','Jagatpura, Jaipur',26.8390,75.8720],['Raja Park Hub','Raja Park','Raja Park, Jaipur',26.9000,75.8230],['Tonk Road Hub','Tonk Road','Tonk Road, Jaipur',26.8810,75.8030],['Bani Park Hub','Bani Park','Bani Park, Jaipur',26.9340,75.7920],['Vidyadhar Nagar Hub','Vidyadhar Nagar','Vidyadhar Nagar, Jaipur',26.9600,75.7790],['Pratap Nagar Hub','Pratap Nagar','Pratap Nagar, Jaipur',26.8010,75.8320],['Sodala Hub','Sodala','Sodala, Jaipur',26.9030,75.7600],['Adarsh Nagar Hub','Adarsh Nagar','Adarsh Nagar, Jaipur',26.8910,75.8240]
    ]; locData.forEach(l=>addLocation.run(...l));
    const firstNames=['Aarav','Aditi','Vihaan','Ananya','Reyansh','Ishita','Kabir','Myra','Arjun','Kiara','Advait','Sara','Dhruv','Riya','Vivaan','Pari','Ishaan','Tara','Krish','Diya','Rudra','Meera','Kiaan','Aanya','Dev'];
    const lastNames=['Sharma','Verma','Gupta','Mehta','Singh','Joshi','Agarwal','Jain','Rathore','Choudhary'];
    const addCustomer=db.prepare('INSERT INTO customers (name,email,phone,location_id) VALUES (?,?,?,?)');
    for(let i=0;i<25;i++) addCustomer.run(`${firstNames[i]} ${lastNames[i%lastNames.length]}`,`customer${i+1}@example.com`,`98${String(10000000+i).slice(-8)}`,(i%12)+1);
    const addRider=db.prepare('INSERT INTO riders (name,phone,vehicle_type,status,rating,location_id) VALUES (?,?,?,?,?,?)');
    const riderNames=['Rohit Kumar','Aman Sharma','Sahil Verma','Neha Singh','Manish Jain','Karan Mehta','Pooja Gupta','Deepak Yadav','Ankit Joshi','Simran Kaur','Rahul Saini','Tushar Raj'];
    const vehicleTypes=['Bike','Scooter','EV','Bike','Scooter','Cycle']; const riderIds=[];
    for(let i=0;i<riderNames.length;i++){const r=addRider.run(riderNames[i],`97${String(10000000+i).slice(-8)}`,vehicleTypes[i%vehicleTypes.length],i===9?'offline':'available',Number((4.2+(i%8)*0.1).toFixed(1)),(i%12)+1);riderIds.push(Number(r.lastInsertRowid));}
    const riderPlatforms=db.prepare('INSERT INTO rider_platforms (rider_id,platform_id) VALUES (?,?)');
    riderIds.forEach((id,i)=>{if([0,3,6,9].includes(i)){for(let p=1;p<=5;p++)riderPlatforms.run(id,p);}else{riderPlatforms.run(id,(i%5)+1);riderPlatforms.run(id,((i+1)%5)+1);if(i%3===0)riderPlatforms.run(id,((i+2)%5)+1);}});
    const addOrder=db.prepare('INSERT INTO orders (order_code,customer_id,platform_id,pickup_location_id,destination_location_id,order_time,promised_at,amount,status) VALUES (?,?,?,?,?,?,?,?,?)');
    const now=new Date(); const datePlus=minutes=>new Date(now.getTime()+minutes*60000).toISOString(); let code=1001;
    for(let i=0;i<50;i++){
      const areaGroup=i<28?Math.floor(i/5)%5:(i%12); const dest=(areaGroup%12)+1; const pickup=((dest+4+(i%3))%12)+1;
      const status=i>=37?(i%4===0?'delivered':'assigned'):'pending'; const minutes=i<28?20+(Math.floor(i/5)*60)+(i%5)*7:(i*3)%240;
      addOrder.run(`ORD-${code++}`,(i%25)+1,(i%5)+1,pickup,dest,datePlus(-10-(i%70)),datePlus(minutes),Number((120+((i*37)%850)).toFixed(2)),status);
    }
    const addBatch=db.prepare('INSERT INTO delivery_batches (batch_code,rider_id,destination_location_id,status,total_orders,estimated_distance_km,estimated_savings_percent,created_at,completed_at) VALUES (?,?,?,?,?,?,?,?,?)');
    const addBatchOrder=db.prepare('INSERT INTO batch_orders (batch_id,order_id,sequence_no) VALUES (?,?,?)');
    const batchSizes=[2,2,2,3,3]; let historicalOrderId=39;
    for(let i=0;i<batchSizes.length;i++){
      const result=addBatch.run(`BAT-H${i+1}`,riderIds[i],i+1,'delivered',batchSizes[i],2.4+i*0.65,18+i*3,datePlus(-1440*(i+1)),datePlus(-1400*(i+1)));
      const batchId=Number(result.lastInsertRowid);
      for(let seq=1;seq<=batchSizes[i];seq++,historicalOrderId++){
        runSeedOrderDelivered(historicalOrderId);
        addBatchOrder.run(batchId,historicalOrderId,seq);
      }
    }
    function runSeedOrderDelivered(orderId){db.prepare("UPDATE orders SET status='delivered' WHERE id=?").run(orderId);}
  });
  seed();
}
seedDatabase();
export default db;
