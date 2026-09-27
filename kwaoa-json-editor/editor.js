let menus = [
  { id: 'menu-001', caption: '商品情報を整理', targetUrl: 'https://chatgpt.com/', prompt: 'このページの情報をもとに商品情報を整理してください。' }
];
const editor = document.getElementById('editor');
const output = document.getElementById('output');
const fileInput = document.getElementById('fileInput');

render(); updateOutput();

document.getElementById('addBtn').addEventListener('click', () => { menus.push({ id: crypto.randomUUID(), caption: '', targetUrl: 'https://chatgpt.com/', prompt: '' }); render(); updateOutput(); });
document.getElementById('previewBtn').addEventListener('click', updateOutput);
document.getElementById('downloadBtn').addEventListener('click', download);
document.getElementById('loadBtn').addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', loadFile);

function render() {
  editor.innerHTML = '';
  menus.forEach((menu, index) => {
    const card = document.createElement('section');
    card.className = 'card';
    card.innerHTML = `
      <div class="head"><strong>${index + 1}</strong><div>
        <button data-action="up" class="secondary">↑</button>
        <button data-action="down" class="secondary">↓</button>
        <button data-action="delete" class="danger">削除</button>
      </div></div>
      <label>ボタン名<input data-field="caption" value="${esc(menu.caption || '')}"></label>
      <label>ChatGPTプロジェクトURL<input data-field="targetUrl" value="${esc(menu.targetUrl || '')}"></label>
      <label>プロンプト<textarea data-field="prompt" rows="6">${esc(menu.prompt || '')}</textarea></label>`;
    card.querySelectorAll('[data-field]').forEach((el) => el.addEventListener('input', () => { menu[el.dataset.field] = el.value; updateOutput(); }));
    card.querySelector('[data-action="up"]').addEventListener('click', () => move(index, -1));
    card.querySelector('[data-action="down"]').addEventListener('click', () => move(index, 1));
    card.querySelector('[data-action="delete"]').addEventListener('click', () => { menus.splice(index, 1); render(); updateOutput(); });
    editor.appendChild(card);
  });
}

function move(index, delta) {
  const n = index + delta;
  if (n < 0 || n >= menus.length) return;
  [menus[index], menus[n]] = [menus[n], menus[index]];
  render(); updateOutput();
}

function updateOutput() {
  const payload = { version: 1, menus: menus.map((m, i) => ({ id: m.id || `menu-${String(i + 1).padStart(3, '0')}`, caption: m.caption, targetUrl: m.targetUrl, prompt: m.prompt })) };
  output.value = JSON.stringify(payload, null, 2);
}

function download() {
  updateOutput();
  const blob = new Blob([output.value], { type: 'application/json;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'kwaoa.json';
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 500);
}

async function loadFile() {
  const file = fileInput.files?.[0];
  if (!file) return;
  const json = JSON.parse(await file.text());
  menus = Array.isArray(json.menus) ? json.menus : [];
  render(); updateOutput();
  fileInput.value = '';
}

function esc(value) {
  return String(value).replace(/[&<>'"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[c]));
}