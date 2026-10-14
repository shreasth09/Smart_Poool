import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import routes from './routes.js';
import './db.js';

const __dirname=path.dirname(fileURLToPath(import.meta.url));
const clientDir=path.resolve(__dirname,'../../client');
const port=Number(process.env.PORT||3000);
const routeList=routes.routes;
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.ico':'image/x-icon'};
function matchRoute(pattern,pathname){
  const keys=[];const escaped=pattern.split('/').map(segment=>{if(segment.startsWith(':')){keys.push(segment.slice(1));return '([^/]+)';}return segment.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}).join('/');
  const match=pathname.match(new RegExp(`^${escaped}/?$`));
  if(!match)return null;const params={};keys.forEach((key,i)=>params[key]=decodeURIComponent(match[i+1]));return params;
}
function sendJson(res,status,body){if(res.writableEnded)return;res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Access-Control-Allow-Origin':'*'});res.end(JSON.stringify(body));}
async function handle(req,res){
  res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','Content-Type');res.setHeader('Access-Control-Allow-Methods','GET,POST,PUT,PATCH,DELETE,OPTIONS');
  if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
  const url=new URL(req.url,'http://localhost');const pathname=decodeURIComponent(url.pathname);
  if(pathname.startsWith('/api')){
    const apiPath=pathname.slice(4)||'/';let body={};
    if(!['GET','HEAD'].includes(req.method)){
      try{let raw='';for await(const chunk of req)raw+=chunk;if(raw)body=JSON.parse(raw);}
      catch{return sendJson(res,400,{success:false,message:'Invalid JSON request body.'});}
    }
    const route=routeList.map(r=>({r,params:matchRoute(r.path,apiPath)})).find(x=>x.r.method===req.method&&x.params!==null);
    if(!route)return sendJson(res,404,{success:false,message:'API endpoint not found.',path:apiPath});
    req.params=route.params;req.body=body;req.query=Object.fromEntries(url.searchParams.entries());
    res.status=function(code){res.statusCode=code;return res;};
    res.json=function(data){return sendJson(res,res.statusCode||200,data);};
    try{const returned=route.r.handler(req,res);if(returned&&typeof returned.then==='function')await returned;if(!res.writableEnded&&res.statusCode>=400)return sendJson(res,res.statusCode,{success:false,message:'Request failed.'});}
    catch(error){console.error('API error:',error);sendJson(res,500,{success:false,message:'Server error: '+error.message});}
    return;
  }
  let requested=pathname==='/'?'index.html':pathname.replace(/^\/+/, '');
  const filePath=path.resolve(clientDir,requested);
  if(!filePath.startsWith(clientDir+path.sep)&&filePath!==path.join(clientDir,'index.html'))return sendJson(res,403,{message:'Forbidden'});
  fs.readFile(filePath,(error,buffer)=>{
    if(error){res.writeHead(404,{'Content-Type':'text/plain; charset=utf-8'});res.end('File not found');return;}
    res.writeHead(200,{'Content-Type':mime[path.extname(filePath)]||'application/octet-stream','Cache-Control':'no-cache'});res.end(buffer);
  });
}
http.createServer(handle).listen(port,()=>console.log(`\n🚚 RouteWise Smart Delivery Pooling is ready.\n🌐 Dashboard: http://localhost:${port}\n🔌 API health: http://localhost:${port}/api/health\n🗄️ SQLite database: server/data/pooling.db\n`));
