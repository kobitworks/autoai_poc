(function(root,factory){
  var api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  root.AutoAIListingExportCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  var CSV_COLUMNS=[
    ['product_code','商品ID'],
    ['title','商品名'],
    ['brand','ブランド'],
    ['category','カテゴリ'],
    ['color','色'],
    ['condition','状態'],
    ['features','特徴'],
    ['description','説明文'],
    ['price','価格'],
    ['currency','通貨'],
    ['quantity','数量'],
    ['image_files','画像ファイル'],
    ['confirmed_at','商品情報確定日時'],
    ['listing_status','出品状態']
  ];

  function clean(value){
    return String(value==null?'':value).replace(/\r\n?/g,'\n').trim();
  }

  function numberOrBlank(value){
    if(value==null||value==='')return '';
    var n=Number(value);
    return Number.isFinite(n)?n:'';
  }

  function buildListingRecord(product){
    product=product||{};
    var confirmed=product.confirmedProduct;
    if(!confirmed||!confirmed.fields)return null;
    var f=confirmed.fields||{};
    var title=clean(f.title);
    if(!title)return null;
    var files=Array.isArray(product.files)?product.files.map(clean).filter(Boolean):[];
    return {
      schema_version:'p013-listing-v1',
      product_code:clean(product.code),
      title:title,
      brand:clean(f.brand),
      category:clean(f.category),
      color:clean(f.color),
      condition:clean(f.condition),
      features:clean(f.features),
      description:clean(f.description),
      price:numberOrBlank(product.listingPrice),
      currency:'JPY',
      quantity:1,
      image_files:files.join(' | '),
      confirmed_at:clean(confirmed.confirmedAt),
      listing_status:'draft'
    };
  }

  function buildListingRecords(products){
    return (products||[]).map(buildListingRecord).filter(Boolean).sort(function(a,b){
      return a.product_code.localeCompare(b.product_code,'ja');
    });
  }

  function protectSpreadsheetFormula(value){
    var s=String(value==null?'':value);
    return /^[\t\r\n ]*[=+\-@]/.test(s)?"'"+s:s;
  }

  function csvCell(value){
    var s=protectSpreadsheetFormula(value).replace(/"/g,'""');
    return '"'+s+'"';
  }

  function toCsv(records){
    records=records||[];
    var header=CSV_COLUMNS.map(function(x){return csvCell(x[1])}).join(',');
    var rows=records.map(function(record){
      return CSV_COLUMNS.map(function(x){return csvCell(record[x[0]])}).join(',');
    });
    return [header].concat(rows).join('\r\n');
  }

  function toCopyText(record){
    return JSON.stringify(record,null,2);
  }

  return {
    CSV_COLUMNS:CSV_COLUMNS.map(function(x){return x.slice()}),
    buildListingRecord:buildListingRecord,
    buildListingRecords:buildListingRecords,
    protectSpreadsheetFormula:protectSpreadsheetFormula,
    toCsv:toCsv,
    toCopyText:toCopyText
  };
});
