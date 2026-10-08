// Character pools for Text Matching Memory
// NOTE: Kanji pools should be provided as curated lists for exact JIS levels.
// This file provides safe defaults; expand as needed.

(function(global){
  const DIGITS = "0123456789".split("");
  const ALPHABETS = "ABCDEFGHJKLMNPQRSTUVWXYZ".split(""); // I,O excluded by default
  const SYMBOLS = [
    "!", "@", "#", "$", "%", "&", "+", "-", "*", "=",
    "◯","●","◎","○","□","■","△","▲","▽","▼","☆","★","◇","◆"
  ];

  // Minimal Kanji samples (placeholders). Replace with full curated lists per your project rules.
  const KANJI_L1 = "日一国人年大十二本中長出三同時行見月後前生五間上東四今金九入学高円子外八六下来気小七山話女北午百書先名川千水半男西電校語土木聞食車何南万毎白天母火右読友左休父雨京".split("");
  const KANJI_L2 = "愛案以位衣医因映英栄塩央横屋温化荷界開階寒感漢館岸起期客急級球究局去橋業曲銀苦具君係軽血決研県庫湖向幸港候航告差菜最材昨刷察参産算仕試資寺持時治辞式識質実写社者取酒受周宿祝術順初所暑助昭消商章勝乗植申身神真深進森整世席昔折説浅戦選然祖送早草争走足即存続卒貸隊代第題達単置注丁調直提転都度徳特毒届内熱念農倍買博半反番必表秒病品負部服福物分別編便勉味命明面問役薬由輸優予養楽利理旅料量輪類令礼和".split("");
  const KANJI_L3 = "𠮟".split(""); // placeholder (rare); replace with curated list if needed

  const HANGUL = [];
  // Build a small hangul pool (가-힣). Use a sampled set for performance.
  const hangulSample = ["가","나","다","라","마","바","사","아","자","차","카","타","파","하","한","글","국","어","사","랑","학","교","세","상","기","억","추","억","빛","꿈"];
  HANGUL.push(...hangulSample);

  const STAGES = [
    { id: 1, label: "数字のみ", pools: { digits: true } },
    { id: 2, label: "アルファベットのみ", pools: { alphabets: true } },
    { id: 3, label: "数字＋アルファベット", pools: { digits: true, alphabets: true } },
    { id: 4, label: "数字＋アルファベット＋記号", pools: { digits: true, alphabets: true, symbols: true } },
    { id: 5, label: "漢字のみ（第一水準）", pools: { kanji1: true } },
    { id: 6, label: "漢字（第一水準）＋数字＋アルファベット＋記号", pools: { kanji1: true, digits: true, alphabets: true, symbols: true } },
    { id: 7, label: "漢字（第一水準、第二水準）＋数字＋アルファベット＋記号", pools: { kanji1: true, kanji2: true, digits: true, alphabets: true, symbols: true } },
    { id: 8, label: "漢字（第一〜第三水準）＋数字＋アルファベット＋記号", pools: { kanji1: true, kanji2: true, kanji3: true, digits: true, alphabets: true, symbols: true } },
    { id: 9, label: "ハングル文字のみ", pools: { hangul: true } },
    { id: 10, label: "漢字（第一〜第三水準）＋ハングル＋数字＋アルファベット＋記号", pools: { kanji1: true, kanji2: true, kanji3: true, hangul: true, digits: true, alphabets: true, symbols: true } },
  ];

  function buildPool(stageId){
    const stage = STAGES.find(s => s.id === stageId) || STAGES[0];
    let pool = [];
    if(stage.pools.digits) pool = pool.concat(DIGITS);
    if(stage.pools.alphabets) pool = pool.concat(ALPHABETS);
    if(stage.pools.symbols) pool = pool.concat(SYMBOLS);
    if(stage.pools.kanji1) pool = pool.concat(KANJI_L1);
    if(stage.pools.kanji2) pool = pool.concat(KANJI_L2);
    if(stage.pools.kanji3) pool = pool.concat(KANJI_L3);
    if(stage.pools.hangul) pool = pool.concat(HANGUL);
    // uniq
    return Array.from(new Set(pool));
  }

  global.TextMatchingMemoryCharset = { STAGES, buildPool };
})(window);
