'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const {MonolinkApiError,createMonolinkApiClient}=require('./api-client.js');

function okPayload(data={ok:true}){
  return {ok:true,status:200,async json(){return {ok:true,request_id:'req-ok',data,meta:{}};}};
}
function errorPayload(status,code,message){
  return {ok:false,status,async json(){return {ok:false,request_id:'req-err',error:{code,message,retry_after_seconds:null}};}};
}

test('base URL未設定では通信しない',async()=>{
  let calls=0;
  const client=createMonolinkApiClient({fetchImpl:async()=>{calls++;return okPayload();}});
  assert.equal(client.isConfigured(),false);
  await assert.rejects(
    ()=>client.publicQuery('monolink.public.item.resolve',{public_token:'abcdefghijklmnop'}),
    err=>err instanceof MonolinkApiError && err.code==='CONFIGURATION_REQUIRED'
  );
  assert.equal(calls,0);
});

test('Access queryは通常route・credential include・共通headerを使う',async()=>{
  const calls=[];
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test/',
    requestIdFactory:()=> 'req-client',
    fetchImpl:async(url,init)=>{calls.push({url,init});return okPayload({item_id:'i1'});}
  });
  await client.query('monolink.item.get',{item_id:'i1'});
  assert.equal(calls[0].url,'https://api.example.test/v1/queries/monolink.item.get');
  assert.equal(calls[0].init.credentials,'include');
  assert.equal(calls[0].init.headers['X-AutoAI-Request'],'1');
  assert.equal(calls[0].init.headers['X-Request-Id'],'req-client');
  assert.equal(calls[0].init.headers['X-AutoAI-Capability'],undefined);
  assert.deepEqual(JSON.parse(calls[0].init.body),{input:{item_id:'i1'}});
});

test('commandは明示Idempotency-Keyなしでは送信しない',async()=>{
  let calls=0;
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async()=>{calls++;return okPayload();}
  });
  await assert.rejects(
    ()=>client.command('monolink.item.update',{item_id:'i1'}),
    err=>err instanceof MonolinkApiError && err.code==='INVALID_REQUEST'
  );
  assert.equal(calls,0);
});

test('public commandはpublic route・credentials omit・Idempotency-Keyを使う',async()=>{
  const calls=[];
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async(url,init)=>{calls.push({url,init});return okPayload({found_report_id:'fr1'});}
  });
  await client.publicCommand(
    'monolink.finder.start',
    {public_token:'abcdefghijklmnop',situation:'IN_HAND'},
    {idempotencyKey:'finder-start-0001'}
  );
  assert.equal(calls[0].url,'https://api.example.test/v1/public/commands/monolink.finder.start');
  assert.equal(calls[0].init.credentials,'omit');
  assert.equal(calls[0].init.headers['Idempotency-Key'],'finder-start-0001');
  assert.equal(calls[0].init.headers['X-AutoAI-Capability'],undefined);
});

test('capability queryはtokenをheaderだけに置きURLへ含めない',async()=>{
  const calls=[];
  const capability='fcap_super_secret_value';
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async(url,init)=>{calls.push({url,init});return okPayload({messages:[]});}
  });
  await client.capabilityQuery(
    'monolink.finder.messages.list',
    {found_report_id:'frp_12345678'},
    {capability}
  );
  assert.equal(calls[0].url,'https://api.example.test/v1/capability/queries/monolink.finder.messages.list');
  assert.equal(calls[0].url.includes(capability),false);
  assert.equal(calls[0].init.headers['X-AutoAI-Capability'],capability);
  assert.equal(calls[0].init.credentials,'omit');
});

test('capability commandはcapabilityとIdempotency-Keyを同時に要求する',async()=>{
  const calls=[];
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async(url,init)=>{calls.push({url,init});return okPayload({replay:false});}
  });
  await client.capabilityCommand(
    'monolink.finder.message.send',
    {found_report_id:'frp_12345678',body:'駅で見つけました'},
    {capability:'fcap_1234567890abcdef',idempotencyKey:'message-send-0001'}
  );
  assert.equal(calls[0].init.headers['X-AutoAI-Capability'],'fcap_1234567890abcdef');
  assert.equal(calls[0].init.headers['Idempotency-Key'],'message-send-0001');
});

test('capability欠落時は通信前に401相当エラー',async()=>{
  let calls=0;
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async()=>{calls++;return okPayload();}
  });
  await assert.rejects(
    ()=>client.capabilityQuery('monolink.finder.messages.list',{found_report_id:'frp_12345678'}),
    err=>err instanceof MonolinkApiError && err.code==='AUTHENTICATION_REQUIRED'
  );
  assert.equal(calls,0);
});

test('API error payloadをstatus/code/requestIdへ写像する',async()=>{
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async()=>errorPayload(409,'IDEMPOTENCY_CONFLICT','conflict')
  });
  await assert.rejects(
    ()=>client.publicCommand(
      'monolink.finder.start',
      {public_token:'abcdefghijklmnop',situation:'IN_HAND'},
      {idempotencyKey:'finder-start-0001'}
    ),
    err=>err instanceof MonolinkApiError &&
      err.status===409 &&
      err.code==='IDEMPOTENCY_CONFLICT' &&
      err.requestId==='req-err'
  );
});

test('public queryとAccess commandのrouteを混同しない',async()=>{
  const calls=[];
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async(url,init)=>{calls.push({url,init});return okPayload();}
  });
  await client.publicQuery('monolink.public.item.resolve',{public_token:'abcdefghijklmnop'});
  await client.command(
    'monolink.lost.open',
    {item_id:'i1',expected_state_version:1},
    {idempotencyKey:'lost-open-0001'}
  );
  assert.equal(calls[0].url,'https://api.example.test/v1/public/queries/monolink.public.item.resolve');
  assert.equal(calls[0].init.credentials,'omit');
  assert.equal(calls[1].url,'https://api.example.test/v1/commands/monolink.lost.open');
  assert.equal(calls[1].init.credentials,'include');
  assert.equal(calls[1].init.headers['Idempotency-Key'],'lost-open-0001');
});

test('operation idにpath注入文字を許可しない',async()=>{
  let calls=0;
  const client=createMonolinkApiClient({
    baseUrl:'https://api.example.test',
    fetchImpl:async()=>{calls++;return okPayload();}
  });
  await assert.rejects(
    ()=>client.publicQuery('../admin',{}),
    err=>err instanceof MonolinkApiError && err.code==='INVALID_REQUEST'
  );
  assert.equal(calls,0);
});
