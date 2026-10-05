const CACHE_NAME='tablet-nav-v05';
const APP_SHELL=['./','./index.html','./manifest.webmanifest','./icon.svg'];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE_NAME).then(cache=>cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET') return;
  const url=new URL(req.url);
  if(url.origin!==self.location.origin) return;
  if(url.pathname.endsWith('/providers.json')) return;
  event.respondWith(
    fetch(req).then(res=>{
      if(res&&res.ok){
        const copy=res.clone();
        caches.open(CACHE_NAME).then(cache=>cache.put(req,copy));
      }
      return res;
    }).catch(()=>caches.match(req).then(hit=>hit||caches.match('./index.html')))
  );
});