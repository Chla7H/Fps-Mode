// NIZAR FPS MEGA FPS UI — protocol matches client.lua (open/close/updateFPS, selectMode, toggleSetting, cleanLag, restartSettings)
let settings = {
    shadows: true,
    particles: true,
    density: true,
    parked: true,
    lod: true,
    lights: true,
    distant: true,
    gen: true,
    fires: true
};

let currentMode = 'normal';

const TOGGLES = ['shadows', 'particles', 'density', 'parked', 'lod', 'lights', 'distant', 'gen', 'fires'];

// ---------- tiny UI sounds (Web Audio, no files) ----------
let actx = null;
function tick(freq) {
    try {
        if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
        if (actx.state === 'suspended') actx.resume();
        const o = actx.createOscillator(), g = actx.createGain();
        o.type = 'square'; o.frequency.value = freq || 700;
        g.gain.setValueAtTime(0.05, actx.currentTime);
        g.gain.exponentialRampToValueAtTime(0.001, actx.currentTime + 0.06);
        o.connect(g); g.connect(actx.destination);
        o.start(); o.stop(actx.currentTime + 0.07);
    } catch (e) {}
}

function GetParentResourceName() {
    try {
        return window.GetParentResourceName();
    } catch (e) {
        return 'fpsmenu';
    }
}

function paintFps(fps) {
    document.getElementById('fps-value').innerText = fps;
    const pct = Math.max(2, Math.min(100, Math.round(fps / 1.2)));
    document.getElementById('fps-fill').style.width = pct + '%';
    const st = document.getElementById('fps-state');
    if (fps >= 50) { st.innerText = 'SMOOTH'; st.style.color = '#ffffff'; }
    else if (fps >= 30) { st.innerText = 'PLAYABLE'; st.style.color = '#ffffff'; }
    else { st.innerText = 'LOW FPS'; st.style.color = '#ee1c3e'; }
}

function paintStatus(name, value) {
    const input = document.getElementById('sw-' + name);
    const row = document.getElementById('row-' + name);
    if (input) input.checked = !!value;
    if (row) row.classList.toggle('off', !value);
}

function paintAll(s) {
    if (!s) return;
    TOGGLES.forEach(function(n) {
        if (s[n] !== undefined) {
            settings[n] = !!s[n];
            paintStatus(n, settings[n]);
        }
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'open') {
        document.getElementById('app').classList.remove('hidden');
        if (data.fps !== undefined) paintFps(data.fps);
        if (data.mode) {
            currentMode = data.mode;
            document.getElementById('current-mode').innerText = data.mode.toUpperCase();
            document.querySelectorAll('.card[data-mode]').forEach(function(btn) {
                btn.classList.toggle('on', btn.dataset.mode === data.mode);
            });
        }
        if (data.settings) paintAll(data.settings);
        if (data.weather) paintWeather(data.weather);
    }

    if (data.action === 'close') {
        document.getElementById('app').classList.add('hidden');
    }

    if (data.action === 'updateFPS') {
        paintFps(data.fps);
    }
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeMenu();
    }
});

function closeMenu() {
    tick(420);
    document.getElementById('app').classList.add('hidden');

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(function() {});
}

function paintWeather(name) {
    document.querySelectorAll('.card[data-weather]').forEach(function(btn) {
        btn.classList.toggle('on', btn.dataset.weather === name);
    });
}

function selectWeather(name) {
    tick(760);
    paintWeather(name);
    fetch(`https://${GetParentResourceName()}/selectWeather`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ weather: name })
    }).catch(function() {});
}

function selectMode(mode) {
    tick(880);
    document.querySelectorAll('.card[data-mode]').forEach(function(btn) {
        btn.classList.remove('on');
    });

    const btn = document.querySelector('[data-mode="' + mode + '"]');
    if (btn) {
        btn.classList.add('on');
    }

    currentMode = mode;
    document.getElementById('current-mode').innerText = mode.toUpperCase();

    fetch(`https://${GetParentResourceName()}/selectMode`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ mode: mode })
    }).catch(function() {});
}

function toggleSetting(name) {
    tick(660);
    const input = document.getElementById('sw-' + name);
    settings[name] = input ? input.checked : !settings[name];
    paintStatus(name, settings[name]);

    fetch(`https://${GetParentResourceName()}/toggleSetting`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({
            setting: name,
            value: settings[name]
        })
    }).catch(function() {});
}

function cleanLag() {
    tick(1000);
    fetch(`https://${GetParentResourceName()}/cleanLag`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(function() {});
}

function restartSettings() {
    tick(500);
    TOGGLES.forEach(function(name) {
        settings[name] = true;
        paintStatus(name, true);
    });

    document.querySelectorAll('.card[data-mode]').forEach(function(btn) {
        btn.classList.remove('on');
    });

    currentMode = 'normal';
    document.getElementById('current-mode').innerText = 'NORMAL';
    paintWeather('sun');

    fetch(`https://${GetParentResourceName()}/restartSettings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(function() {});
}

/* Card follows the mouse: smooth 3D tilt + movement + light */
(function() {
    const panel = document.getElementById('panel');
    if (!panel) return;
    let tx = 0, ty = 0, cx = 0, cy = 0, running = false;

    function frame() {
        cx += (tx - cx) * 0.14;
        cy += (ty - cy) * 0.14;
        panel.style.transform = 'perspective(900px) translate(' + (-cx * 50) + 'px,' + (-cy * 36) + 'px) rotateY(' + (-cx * 30) + 'deg) rotateX(' + (cy * 24) + 'deg) rotateZ(-1deg)';
        if (Math.abs(tx - cx) > 0.001 || Math.abs(ty - cy) > 0.001) {
            requestAnimationFrame(frame);
        } else {
            running = false;
        }
    }

    document.addEventListener('mousemove', function(e) {
        tx = e.clientX / window.innerWidth - 0.5;
        ty = e.clientY / window.innerHeight - 0.5;
        const r = panel.getBoundingClientRect();
        panel.style.setProperty('--mx', (e.clientX - r.left) + 'px');
        panel.style.setProperty('--my', (e.clientY - r.top + panel.scrollTop) + 'px');
        if (!running) { running = true; requestAnimationFrame(frame); }
    });

    frame();
})();
