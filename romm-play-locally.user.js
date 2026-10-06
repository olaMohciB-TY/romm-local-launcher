// ==UserScript==
// @name         RomM Play Locally
// @namespace    romm-local-launcher
// @version      0.1
// @description  Adds a floating "Play Locally" button that opens a romm:// link
// @match        http://romm.casa:8085/*
// @match        http://192.168.1.151:8085/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const BUTTON_ID = 'romm-play-locally-btn';

  function getRomId() {
    const m = location.pathname.match(/\/rom\/(\d+)/);
    return m ? m[1] : null;
  }

  function buildLink(romId) {
    return 'romm://play/' + romId + '?server=' + encodeURIComponent(location.origin);
  }

  function update() {
    const romId = getRomId();
    let btn = document.getElementById(BUTTON_ID);

    if (!romId) {
      if (btn) btn.remove();
      return;
    }

    if (!btn) {
      btn = document.createElement('a');
      btn.id = BUTTON_ID;
      btn.textContent = 'Play Locally';
      btn.style.cssText = [
        'position:fixed', 'bottom:20px', 'right:20px', 'z-index:99999',
        'padding:12px 18px', 'background:#8b74bd', 'color:#fff',
        'font:600 14px sans-serif', 'border-radius:8px',
        'text-decoration:none', 'box-shadow:0 2px 8px rgba(0,0,0,.4)',
        'cursor:pointer'
      ].join(';');
      document.body.appendChild(btn);
    }
    btn.href = buildLink(romId);
  }

  update();
  setInterval(update, 1000);
})();