'use strict';

(function(root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.AutoAIQRGrouping = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  var PRODUCT_RE = /QPMS[0-9]{16}/i;

  function uniq(a) {
    var out = [];
    (a || []).forEach(function(x) {
      if (x && out.indexOf(x) < 0) out.push(x);
    });
    return out;
  }

  function ext(x) {
    var m = String((x && x.originalName) || '').match(/\.([a-z0-9]{2,5})$/i);
    return m ? m[1].toLowerCase() : ((x && x.mimeType) === 'image/png' ? 'png' : 'jpg');
  }

  function validCode(s) {
    return /^QPMS[0-9]{16}$/.test(String(s || '').toUpperCase());
  }

  function norm(raw) {
    var s = String(raw || '').trim();
    if (!s) return '';
    try { s = decodeURIComponent(s); } catch (_) {}
    var m = s.match(PRODUCT_RE);
    return m ? m[0].toUpperCase() : '';
  }

  function applyVirtualNames(groups) {
    Object.keys(groups).sort().forEach(function(code) {
      groups[code]
        .sort(function(a, b) {
          return String(a.originalName || '').localeCompare(String(b.originalName || ''), 'ja');
        })
        .forEach(function(x, i) {
          x.virtualName = code + '_' + String(i + 1).padStart(2, '0') + '.' + ext(x);
        });
    });
    return groups;
  }

  function groupImages(images) {
    var groups = {}, unresolved = [];
    (images || []).forEach(function(x) {
      if (validCode(x && x.qrCode) && (x.status === 'grouped' || x.status === 'manual')) {
        (groups[x.qrCode] || (groups[x.qrCode] = [])).push(x);
      } else {
        unresolved.push(x);
      }
    });
    applyVirtualNames(groups);
    return { groups: groups, unresolved: unresolved };
  }

  return {
    PRODUCT_RE: PRODUCT_RE,
    uniq: uniq,
    ext: ext,
    validCode: validCode,
    norm: norm,
    applyVirtualNames: applyVirtualNames,
    groupImages: groupImages
  };
});
