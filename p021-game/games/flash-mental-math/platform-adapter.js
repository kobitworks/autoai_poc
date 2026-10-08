(function(){
  const KEY='p021.game-g012.best';
  function best(score){const prev=Number(localStorage.getItem(KEY)||-1);if(score>prev)localStorage.setItem(KEY,String(score));return Math.max(score,prev);}
  function finish(score,meta){
    const high=best(Number(score)||0);
    const wrap=document.createElement('div');
    wrap.dataset.result='true';
    wrap.style.cssText='position:fixed;inset:0;z-index:9999;background:rgba(15,23,42,.72);display:grid;place-items:center;padding:18px';
    wrap.innerHTML='<section role="dialog" aria-modal="true" style="width:min(420px,100%);background:#fff;border-radius:18px;padding:22px;text-align:center;box-shadow:0 24px 60px #0004"><h2 style="margin:0 0 8px">RESULT</h2><p style="font-size:34px;font-weight:900;margin:8px 0">'+score+' / '+meta.rounds+'</p><p style="color:#667085">BEST '+high+' ・ Stage '+meta.stage+' ・ Lv'+meta.level+'</p><div style="display:flex;gap:10px"><button id="p021Retry" style="flex:1;padding:12px;border:0;border-radius:12px;font-weight:800">もう一度</button><button id="p021Home" style="flex:1;padding:12px;border:0;border-radius:12px;font-weight:800">ゲーム一覧</button></div></section>';
    document.body.appendChild(wrap);
    wrap.querySelector('#p021Retry').onclick=()=>location.reload();
    wrap.querySelector('#p021Home').onclick=()=>location.href='../../';
  }
  function back_to_top(){location.href='../../';}
  window.platform_sdk={finish,back_to_top};
})();