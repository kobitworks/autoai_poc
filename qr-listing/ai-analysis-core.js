(function(root,factory){
  var api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  root.AutoAIAIAnalysisCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  function clamp(x,min,max){return Math.max(min,Math.min(max,x));}
  function norm(s){return String(s==null?'':s).trim().toLowerCase();}

  var LABELS=[
    [/\b(sneaker|running shoe|shoe|loafer|sandal|boot)\b/i,'靴'],
    [/\b(backpack|handbag|purse|wallet|briefcase|bag)\b/i,'バッグ'],
    [/\b(watch|wristwatch|clock)\b/i,'時計'],
    [/\b(camera|lens|tripod)\b/i,'カメラ'],
    [/\b(laptop|notebook computer|keyboard|mouse|monitor)\b/i,'PC・周辺機器'],
    [/\b(cellular telephone|cellphone|mobile phone|smartphone)\b/i,'スマートフォン'],
    [/\b(television|speaker|headphone|earphone|radio)\b/i,'家電・オーディオ'],
    [/\b(jersey|shirt|t-shirt|sweatshirt|coat|jacket|jean|skirt|dress|cardigan|suit)\b/i,'ファッション'],
    [/\b(chair|sofa|couch|table|desk|cabinet|bookcase|wardrobe)\b/i,'家具'],
    [/\b(mug|cup|bottle|plate|dish|bowl|teapot|coffee pot)\b/i,'キッチン・食器'],
    [/\b(book|comic|notebook|binder)\b/i,'本・文具'],
    [/\b(toy|doll|teddy|game|joystick)\b/i,'ホビー'],
    [/\b(bicycle|mountain bike|motor scooter|car|sports car)\b/i,'乗り物・用品']
  ];

  function categoryFromLabels(items){
    var text=(items||[]).map(function(x){return x.label||''}).join(' ');
    for(var i=0;i<LABELS.length;i++)if(LABELS[i][0].test(text))return LABELS[i][1];
    return 'その他・要確認';
  }

  function friendlyLabel(label){
    var s=String(label||'').split(',')[0].trim();
    var pairs=[
      [/running shoe|sneaker/i,'スニーカー'],[/loafer/i,'ローファー'],[/sandal/i,'サンダル'],[/boot/i,'ブーツ'],
      [/backpack/i,'バックパック'],[/handbag|purse/i,'バッグ'],[/wallet/i,'財布'],[/watch|wristwatch/i,'腕時計'],
      [/laptop|notebook computer/i,'ノートPC'],[/cellular telephone|cellphone|mobile phone|smartphone/i,'スマートフォン'],
      [/camera/i,'カメラ'],[/jersey|shirt|t-shirt/i,'トップス'],[/coat|jacket/i,'ジャケット'],
      [/mug|cup/i,'カップ'],[/bottle/i,'ボトル'],[/chair/i,'チェア'],[/book/i,'書籍']
    ];
    for(var i=0;i<pairs.length;i++)if(pairs[i][0].test(s))return pairs[i][1];
    return s||'商品';
  }

  function colorName(rgb){
    rgb=rgb||{};
    var r=clamp(Number(rgb.r)||0,0,255),g=clamp(Number(rgb.g)||0,0,255),b=clamp(Number(rgb.b)||0,0,255);
    var max=Math.max(r,g,b),min=Math.min(r,g,b),avg=(r+g+b)/3,delta=max-min;
    if(max<45)return '黒';
    if(min>225&&delta<25)return '白';
    if(delta<22)return avg>175?'ライトグレー':avg>95?'グレー':'ダークグレー';
    var rr=r/255,gg=g/255,bb=b/255,mx=Math.max(rr,gg,bb),mn=Math.min(rr,gg,bb),d=mx-mn,h=0;
    if(d){
      if(mx===rr)h=60*(((gg-bb)/d)%6);
      else if(mx===gg)h=60*(((bb-rr)/d)+2);
      else h=60*(((rr-gg)/d)+4);
    }
    if(h<0)h+=360;
    var s=mx===0?0:d/mx;
    if(s<0.18)return avg>180?'ライトグレー':'グレー';
    if(h>=15&&h<48&&mx<0.72)return 'ブラウン';
    if(h<15||h>=345)return '赤';
    if(h<45)return 'オレンジ';
    if(h<70)return '黄';
    if(h<165)return '緑';
    if(h<195)return 'シアン';
    if(h<255)return '青';
    if(h<300)return '紫';
    if(h<345)return 'ピンク';
    return '要確認';
  }

  function aggregate(perImage){
    var map={};
    (perImage||[]).forEach(function(list){
      (list||[]).forEach(function(x){
        var key=norm(x.label);
        if(!key)return;
        if(!map[key])map[key]={label:String(x.label),sum:0,max:0,count:0};
        var score=Number(x.score)||0;
        map[key].sum+=score;map[key].max=Math.max(map[key].max,score);map[key].count++;
      });
    });
    return Object.values(map).map(function(x){
      return {label:x.label,score:(x.sum/x.count),maxScore:x.max,imageCount:x.count};
    }).sort(function(a,b){return (b.score*0.7+b.maxScore*0.3)-(a.score*0.7+a.maxScore*0.3)}).slice(0,8);
  }

  function scoreText(x){return Math.round(clamp(Number(x)||0,0,1)*100)+'%';}

  function buildFields(input){
    input=input||{};
    var labels=input.labels||[],top=labels[0]||{label:'商品',score:0};
    var existing=input.existing||{};
    var category=existing.category||categoryFromLabels(labels);
    var color=existing.color||colorName(input.dominantColor);
    var title=existing.title||friendlyLabel(top.label);
    var brand=existing.brand||'';
    var condition=existing.condition||'要確認';
    var features=labels.slice(0,3).map(function(x){return friendlyLabel(x.label)+' '+scoreText(x.score)}).join(' / ');
    if(!features)features='画像AIの分類候補なし';
    var photoCount=Number(input.photoCount)||0;
    var description='画像AIの候補では「'+friendlyLabel(top.label)+'」に近い物品として認識されました。主な色候補は'+color+'、写真は'+photoCount+'枚です。ブランド・型番・状態は画像だけで確定せず、出品前に必ず確認してください。';
    return {
      title:title,
      brand:brand,
      category:category,
      color:color,
      condition:condition,
      features:features,
      description:existing.description||description
    };
  }

  return {
    aggregate:aggregate,
    categoryFromLabels:categoryFromLabels,
    colorName:colorName,
    friendlyLabel:friendlyLabel,
    buildFields:buildFields,
    scoreText:scoreText
  };
});
