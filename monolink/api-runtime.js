'use strict';

(function(root,factory){
  if(typeof module!=='undefined'&&module.exports){
    module.exports=factory(require('./api-client.js'));
  }else{
    root.MonolinkApiRuntime=factory(root.MonolinkApiClient);
  }
})(typeof globalThis!=='undefined'?globalThis:this,function(api){
  if(!api||typeof api.createMonolinkApiClient!=='function'){
    throw new Error('MonolinkApiClient is required before MonolinkApiRuntime');
  }

  function createMonolinkApiRuntime(options={}){
    const client=api.createMonolinkApiClient({
      baseUrl:options.baseUrl,
      fetchImpl:options.fetchImpl,
      requestIdFactory:options.requestIdFactory
    });
    const apiEnabled=client.isConfigured();

    const runtime={
      mode:()=>apiEnabled?'api':'mock',
      isApiEnabled:()=>apiEnabled,
      async run({mock,api:apiAction}={}){
        if(!apiEnabled){
          if(typeof mock!=='function') throw new TypeError('mock action is required when API is disabled');
          return {mode:'mock',value:await mock()};
        }
        if(typeof apiAction!=='function') throw new TypeError('api action is required when API is enabled');
        return {mode:'api',value:await apiAction(runtime)};
      },
      query:(operationId,input,opts)=>client.query(operationId,input,opts),
      command:(operationId,input,opts)=>client.command(operationId,input,opts),
      publicQuery:(operationId,input,opts)=>client.publicQuery(operationId,input,opts),
      publicCommand:(operationId,input,opts)=>client.publicCommand(operationId,input,opts),
      capabilityQuery:(operationId,input,opts)=>client.capabilityQuery(operationId,input,opts),
      capabilityCommand:(operationId,input,opts)=>client.capabilityCommand(operationId,input,opts)
    };
    return Object.freeze(runtime);
  }

  return Object.freeze({createMonolinkApiRuntime});
});
