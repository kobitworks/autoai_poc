(function(root,factory){
  var api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  root.AutoAIProductConfirmationCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  var FIELD_KEYS=['title','brand','category','color','condition','features','description'];

  function normalizeFields(input){
    input=input||{};
    var out={};
    FIELD_KEYS.forEach(function(key){
      out[key]=String(input[key]==null?'':input[key]).trim();
    });
    return out;
  }

  function validateFields(input){
    var fields=normalizeFields(input),errors=[];
    if(!fields.title){
      errors.push({field:'title',code:'TITLE_REQUIRED',message:'商品名を入力してください。'});
    }
    return {ok:errors.length===0,errors:errors,fields:fields};
  }

  function buildConfirmedProduct(input){
    input=input||{};
    var checked=validateFields(input.fields);
    if(!checked.ok){
      var err=new Error(checked.errors[0].message);
      err.code=checked.errors[0].code;
      err.errors=checked.errors;
      throw err;
    }
    var confirmedAt=String(input.confirmedAt||'').trim();
    if(!confirmedAt){
      var e=new Error('confirmedAt is required');
      e.code='CONFIRMED_AT_REQUIRED';
      throw e;
    }
    return {
      fields:checked.fields,
      confirmedAt:confirmedAt,
      source:'human-reviewed-ai-candidate',
      sourceAnalysisExecutedAt:String(input.sourceAnalysisExecutedAt||'').trim(),
      sourceCandidateSavedAt:String(input.sourceCandidateSavedAt||'').trim()
    };
  }

  return {
    FIELD_KEYS:FIELD_KEYS.slice(),
    normalizeFields:normalizeFields,
    validateFields:validateFields,
    buildConfirmedProduct:buildConfirmedProduct
  };
});
