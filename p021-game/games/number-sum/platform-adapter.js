(function(){
  'use strict';
  const portalUrl='../../';
  window.platform_sdk={
    finish:function(score,meta){
      window.dispatchEvent(new CustomEvent('p021:game-finish',{detail:{gameId:'GAME-G009',score:score,meta:meta||{}}}));
      const status=document.getElementById('status');
      if(status) status.textContent='クリア！ GAME-G009 Number Sum';
    },
    back_to_top:function(){ location.href=portalUrl; }
  };
  function bind(){
    const home=document.getElementById('btnTop');
    if(home) home.addEventListener('click',function(){ window.platform_sdk.back_to_top(); });
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',bind); else bind();
})();