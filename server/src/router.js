export function Router(){
  const routes=[];
  const router={routes};
  for(const method of ['get','post','put','patch','delete']) router[method]=(path,handler)=>{routes.push({method:method.toUpperCase(),path,handler});return router;};
  return router;
}
