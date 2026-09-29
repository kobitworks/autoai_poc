'use strict';

(function(root,factory){
  const api=factory();
  if(typeof module!=='undefined'&&module.exports) module.exports=api;
  root.MonolinkApiClient=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  const OPERATION_RE=/^[A-Za-z0-9._-]{1,160}$/;
  const IDEMPOTENCY_RE=/^[A-Za-z0-9._:-]{8,200}$/;

  class MonolinkApiError extends Error{
    constructor(message,{status=0,code='INTERNAL_ERROR',requestId=null,retryAfterSeconds=null}={}){
      super(message);
      this.name='MonolinkApiError';
      this.status=status;
      this.code=code;
      this.requestId=requestId;
      this.retryAfterSeconds=retryAfterSeconds;
    }
  }

  function trimBaseUrl(value){
    return String(value||'').trim().replace(/\/+$/,'');
  }

  function assertOperation(operationId){
    const id=String(operationId||'');
    if(!OPERATION_RE.test(id)) throw new MonolinkApiError('Operation id is invalid',{code:'INVALID_REQUEST'});
    return id;
  }

  function assertIdempotencyKey(value){
    const key=String(value||'').trim();
    if(!IDEMPOTENCY_RE.test(key)){
      throw new MonolinkApiError('A valid Idempotency-Key is required',{code:'INVALID_REQUEST'});
    }
    return key;
  }

  function assertCapability(value){
    const token=String(value||'').trim();
    if(!token) throw new MonolinkApiError('Finder capability is required',{code:'AUTHENTICATION_REQUIRED'});
    return token;
  }

  function route(surface,kind,operationId){
    const op=encodeURIComponent(assertOperation(operationId));
    if(surface==='access') return '/v1/'+(kind==='query'?'queries':'commands')+'/'+op;
    if(surface==='public') return '/v1/public/'+(kind==='query'?'queries':'commands')+'/'+op;
    if(surface==='capability') return '/v1/capability/'+(kind==='query'?'queries':'commands')+'/'+op;
    throw new MonolinkApiError('API surface is invalid',{code:'INVALID_REQUEST'});
  }

  async function readJson(response){
    try{return await response.json()}catch(_){
      throw new MonolinkApiError('API response was not valid JSON',{
        status:Number(response&&response.status)||0,
        code:'INTERNAL_ERROR'
      });
    }
  }

  function createMonolinkApiClient(options={}){
    const baseUrl=trimBaseUrl(options.baseUrl);
    const fetchImpl=options.fetchImpl || (typeof fetch==='function'?fetch.bind(globalThis):null);
    const defaultRequestIdFactory=options.requestIdFactory || null;

    async function invoke(surface,kind,operationId,input={},requestOptions={}){
      if(!baseUrl){
        throw new MonolinkApiError('API base URL is not configured',{code:'CONFIGURATION_REQUIRED'});
      }
      if(typeof fetchImpl!=='function'){
        throw new MonolinkApiError('Fetch implementation is not available',{code:'CONFIGURATION_REQUIRED'});
      }

      const path=route(surface,kind,operationId);
      const headers={
        'Content-Type':'application/json',
        'X-AutoAI-Request':'1'
      };

      const requestId=String(
        requestOptions.requestId ||
        (typeof defaultRequestIdFactory==='function'?defaultRequestIdFactory():'') ||
        ''
      ).trim();
      if(requestId) headers['X-Request-Id']=requestId;

      if(kind==='command'){
        headers['Idempotency-Key']=assertIdempotencyKey(requestOptions.idempotencyKey);
      }
      if(surface==='capability'){
        headers['X-AutoAI-Capability']=assertCapability(requestOptions.capability);
      }

      const response=await fetchImpl(baseUrl+path,{
        method:'POST',
        headers,
        credentials:surface==='access'?'include':'omit',
        cache:'no-store',
        body:JSON.stringify({input:input==null?{}:input})
      });
      const payload=await readJson(response);

      if(!response.ok || payload?.ok===false){
        const err=payload&&payload.error?payload.error:{};
        throw new MonolinkApiError(
          String(err.message || 'API request failed'),
          {
            status:Number(response.status)||0,
            code:String(err.code || 'INTERNAL_ERROR'),
            requestId:payload&&payload.request_id?String(payload.request_id):null,
            retryAfterSeconds:err.retry_after_seconds==null?null:Number(err.retry_after_seconds)
          }
        );
      }
      return payload;
    }

    return Object.freeze({
      isConfigured:()=>Boolean(baseUrl),
      query:(operationId,input,opts)=>invoke('access','query',operationId,input,opts),
      command:(operationId,input,opts)=>invoke('access','command',operationId,input,opts),
      publicQuery:(operationId,input,opts)=>invoke('public','query',operationId,input,opts),
      publicCommand:(operationId,input,opts)=>invoke('public','command',operationId,input,opts),
      capabilityQuery:(operationId,input,opts)=>invoke('capability','query',operationId,input,opts),
      capabilityCommand:(operationId,input,opts)=>invoke('capability','command',operationId,input,opts)
    });
  }

  return Object.freeze({
    MonolinkApiError,
    createMonolinkApiClient
  });
});
