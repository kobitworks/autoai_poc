'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const {createMonolinkApiRuntime}=require('./api-runtime.js');

function okPayload(data={}){
  return {ok:true,status:200,async json(){return {ok:true,request_id:'req-runtime',data,meta:{}};}};
}

test('mock mode executes local action and never fetches when base URL is unset',async()=>{
  let fetchCalls=0;
  let apiCalls=0;
  const runtime=createMonolinkApiRuntime({
    fetchImpl:async()=>{fetchCalls++;return okPayload();}
  });

  const result=await runtime.run({
    mock:()=>({saved:'memory-only'}),
    api:async()=>{apiCalls++;return {saved:'remote'};}
  });

  assert.equal(runtime.mode(),'mock');
  assert.equal(runtime.isApiEnabled(),false);
  assert.deepEqual(result,{mode:'mock',value:{saved:'memory-only'}});
  assert.equal(fetchCalls,0);
  assert.equal(apiCalls,0);
});

test('configured mode routes through the existing adapter instead of the mock action',async()=>{
  const calls=[];
  let mockCalls=0;
  const runtime=createMonolinkApiRuntime({
    baseUrl:'https://api.example.test/',
    fetchImpl:async(url,init)=>{
      calls.push({url,init});
      return okPayload({item_status:'ACTIVE'});
    }
  });

  const result=await runtime.run({
    mock:()=>{mockCalls++;return {item_status:'MOCK'};},
    api:api=>api.publicQuery(
      'monolink.public.item.resolve',
      {public_token:'abcdefghijklmnop'}
    )
  });

  assert.equal(runtime.mode(),'api');
  assert.equal(runtime.isApiEnabled(),true);
  assert.equal(mockCalls,0);
  assert.equal(calls.length,1);
  assert.equal(calls[0].url,'https://api.example.test/v1/public/queries/monolink.public.item.resolve');
  assert.equal(calls[0].init.credentials,'omit');
  assert.equal(result.mode,'api');
  assert.equal(result.value.data.item_status,'ACTIVE');
});

test('runtime exposes all six adapter surfaces without storing credentials',()=>{
  const runtime=createMonolinkApiRuntime({});
  for(const name of [
    'query',
    'command',
    'publicQuery',
    'publicCommand',
    'capabilityQuery',
    'capabilityCommand'
  ]){
    assert.equal(typeof runtime[name],'function',name+' should be available');
  }
});

test('configured mode requires an explicit API action before any request',async()=>{
  let fetchCalls=0;
  const runtime=createMonolinkApiRuntime({
    baseUrl:'https://api.example.test',
    fetchImpl:async()=>{fetchCalls++;return okPayload();}
  });

  await assert.rejects(
    ()=>runtime.run({mock:()=>({})}),
    err=>err instanceof TypeError && /api action/.test(err.message)
  );
  assert.equal(fetchCalls,0);
});
