(function(){
'use strict';

var DB='autoai-qr-listing-poc',VER=2;

function request(r){
  return new Promise(function(ok,ng){
    r.onsuccess=function(){ok(r.result)};
    r.onerror=function(){ng(r.error)};
  });
}

function done(t){
  return new Promise(function(ok,ng){
    t.oncomplete=function(){ok()};
    t.onerror=function(){ng(t.error)};
    t.onabort=function(){ng(t.error)};
  });
}

function open(){
  return new Promise(function(ok,ng){
    var r=indexedDB.open(DB,VER);
    r.onupgradeneeded=function(){
      var d=r.result,tx=r.transaction,s;
      if(!d.objectStoreNames.contains('images')){
        s=d.createObjectStore('images',{keyPath:'id'});
        s.createIndex('batchId','batchId',{unique:false});
        s.createIndex('qrCode','qrCode',{unique:false});
      }else{
        s=tx.objectStore('images');
        if(!s.indexNames.contains('batchId'))s.createIndex('batchId','batchId',{unique:false});
        if(!s.indexNames.contains('qrCode'))s.createIndex('qrCode','qrCode',{unique:false});
      }
      if(!d.objectStoreNames.contains('products')){
        s=d.createObjectStore('products',{keyPath:'code'});
        s.createIndex('updatedAt','updatedAt',{unique:false});
        s.createIndex('status','status',{unique:false});
      }else{
        s=tx.objectStore('products');
        if(!s.indexNames.contains('updatedAt'))s.createIndex('updatedAt','updatedAt',{unique:false});
        if(!s.indexNames.contains('status'))s.createIndex('status','status',{unique:false});
      }
    };
    r.onsuccess=function(){ok(r.result)};
    r.onerror=function(){ng(r.error)};
  });
}

function unique(a){
  var out=[];
  (a||[]).forEach(function(x){if(x&&out.indexOf(x)<0)out.push(x)});
  return out;
}

async function saveImages(files,batchId){
  var d=await open(),t=d.transaction('images','readwrite'),s=t.objectStore('images');
  var now=new Date().toISOString(),out=[];
  Array.from(files||[]).forEach(function(f,i){
    var x={
      id:crypto.randomUUID(),
      batchId:batchId,
      originalName:f.name||('image-'+(i+1)+'.jpg'),
      mimeType:f.type||'image/jpeg',
      size:f.size||0,
      createdAt:now,
      updatedAt:now,
      qrCode:'',
      productCode:'',
      virtualName:'',
      status:'uploaded',
      blob:f
    };
    s.put(x);
    out.push(x);
  });
  await done(t);d.close();return out;
}

async function allImages(){
  var d=await open(),t=d.transaction('images','readonly');
  var a=await request(t.objectStore('images').getAll());
  await done(t);d.close();return a||[];
}

async function getImages(batchId){
  var d=await open(),t=d.transaction('images','readonly'),s=t.objectStore('images'),a;
  if(s.indexNames.contains('batchId'))a=await request(s.index('batchId').getAll(batchId));
  else a=(await request(s.getAll())).filter(function(x){return x.batchId===batchId});
  await done(t);d.close();
  return (a||[]).sort(function(x,y){return String(x.originalName||'').localeCompare(String(y.originalName||''),'ja')});
}

async function listBatches(){
  var a=await allImages(),m={};
  a.forEach(function(x){
    if(!m[x.batchId])m[x.batchId]={batchId:x.batchId,count:0,createdAt:x.createdAt};
    m[x.batchId].count++;
    if(String(x.createdAt||'')>String(m[x.batchId].createdAt||''))m[x.batchId].createdAt=x.createdAt;
  });
  return Object.values(m).sort(function(x,y){return String(y.createdAt||'').localeCompare(String(x.createdAt||''))});
}

async function updateImage(id,patch){
  var d=await open(),t=d.transaction('images','readwrite'),s=t.objectStore('images');
  var x=await request(s.get(id));
  if(!x){d.close();throw new Error('IMAGE_NOT_FOUND: '+id)}
  Object.assign(x,patch||{}, {updatedAt:new Date().toISOString()});
  s.put(x);
  await done(t);d.close();return x;
}

async function getProduct(code){
  var d=await open(),t=d.transaction('products','readonly');
  var x=await request(t.objectStore('products').get(code));
  await done(t);d.close();return x||null;
}

async function putProduct(input){
  if(!input||!input.code)throw new Error('PRODUCT_CODE_REQUIRED');
  var d=await open(),t=d.transaction('products','readwrite'),s=t.objectStore('products');
  var old=await request(s.get(input.code));
  var now=new Date().toISOString();
  var x=Object.assign({},old||{},input,{
    code:String(input.code),
    createdAt:(old&&old.createdAt)||input.createdAt||now,
    updatedAt:now,
    storageMode:'indexeddb-poc'
  });
  if(!x.status)x.status='grouped';
  s.put(x);
  await done(t);d.close();return x;
}

async function listProducts(){
  var d=await open(),t=d.transaction('products','readonly');
  var a=await request(t.objectStore('products').getAll());
  await done(t);d.close();
  return (a||[]).sort(function(x,y){return String(y.updatedAt||'').localeCompare(String(x.updatedAt||''))});
}

async function getProductImages(code){
  var a=await allImages();
  return a.filter(function(x){
    return (x.productCode===code||x.qrCode===code)&&(x.status==='grouped'||x.status==='manual');
  }).sort(function(x,y){
    return String(x.virtualName||x.originalName||'').localeCompare(String(y.virtualName||y.originalName||''),'ja');
  });
}

async function syncProducts(groups,batchId){
  groups=groups||{};
  var codes=Object.keys(groups),now=new Date().toISOString();
  var d=await open(),t=d.transaction('images','readwrite'),s=t.objectStore('images');
  codes.forEach(function(code){
    (groups[code]||[]).forEach(function(item){
      var x=Object.assign({},item,{
        qrCode:code,
        productCode:code,
        virtualName:item.virtualName||'',
        updatedAt:now
      });
      s.put(x);
    });
  });
  await done(t);d.close();

  var all=await allImages();
  for(var i=0;i<codes.length;i++){
    var code=codes[i];
    var linked=all.filter(function(x){
      return (x.productCode===code||x.qrCode===code)&&(x.status==='grouped'||x.status==='manual');
    }).sort(function(x,y){
      return String(x.virtualName||x.originalName||'').localeCompare(String(y.virtualName||y.originalName||''),'ja');
    });
    var old=await getProduct(code);
    await putProduct(Object.assign({},old||{},{
      code:code,
      qrCode:code,
      batchId:batchId||((linked[0]&&linked[0].batchId)||''),
      batchIds:unique(linked.map(function(x){return x.batchId})),
      imageIds:linked.map(function(x){return x.id}),
      imageCount:linked.length,
      files:linked.map(function(x){return x.virtualName||x.originalName}),
      status:(old&&old.status)||'grouped',
      processingState:(old&&old.processingState)||'qr_grouped',
      storageMode:'indexeddb-poc'
    }));
  }
  return listProducts();
}

async function getStorageSummary(){
  var images=await allImages(),products=await listProducts();
  return {
    images:images.length,
    products:products.length,
    bytes:images.reduce(function(sum,x){return sum+Number(x.size||0)},0),
    storageMode:'indexeddb-poc'
  };
}

window.AutoAIStore={
  saveImages:saveImages,
  getImages:getImages,
  listBatches:listBatches,
  updateImage:updateImage,
  putProduct:putProduct,
  getProduct:getProduct,
  listProducts:listProducts,
  getProductImages:getProductImages,
  syncProducts:syncProducts,
  getStorageSummary:getStorageSummary
};
})();