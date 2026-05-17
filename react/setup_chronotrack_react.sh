#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     Connected ChronoTrack — Setup React + Vite + Firebase   ║
# ║     Sans Homebrew, sans droits admin                        ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

PROJECT="$HOME/chronotrack-react"
NODE_VERSION="20.11.0"
NODE_DIR="$HOME/.node"

echo ""
echo "🚀 Setup ChronoTrack React + Firebase..."
echo ""

# ── 1. Installer Node.js si absent ────────────────────────────
if ! command -v node &>/dev/null; then
  echo "📦 Installation de Node.js $NODE_VERSION..."
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.gz"
  else
    NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-x64.tar.gz"
  fi
  mkdir -p "$NODE_DIR"
  curl -L "$NODE_URL" | tar -xz -C "$NODE_DIR" --strip-components=1
  export PATH="$NODE_DIR/bin:$PATH"
  # Ajouter au PATH permanent
  if ! grep -q 'node/bin' ~/.zshrc 2>/dev/null; then
    echo '' >> ~/.zshrc
    echo '# Node.js — ChronoTrack' >> ~/.zshrc
    echo 'export PATH="$HOME/.node/bin:$PATH"' >> ~/.zshrc
  fi
  echo "✅ Node.js installé : $(node --version)"
else
  echo "✅ Node.js déjà présent : $(node --version)"
  export PATH="$NODE_DIR/bin:$PATH"
fi

# ── 2. Créer le projet Vite + React ───────────────────────────
echo ""
echo "📁 Création du projet React..."

if [ -d "$PROJECT" ]; then
  echo "⚠️  $PROJECT existe déjà."
  read -p "   Supprimer et recréer ? (o/n) : " confirm
  if [ "$confirm" = "o" ]; then rm -rf "$PROJECT"; else echo "Annulé."; exit 0; fi
fi

npx create-vite@5.5.2 chronotrack-react --template react
mv chronotrack-react "$HOME/"
cd "$PROJECT"
npm install

# ── 3. Installer Firebase ─────────────────────────────────────
echo ""
echo "📦 Installation de Firebase..."
npm install firebase

# ── 4. Créer la structure du projet ───────────────────────────
echo ""
echo "📂 Création de la structure..."
mkdir -p src/firebase src/hooks src/components src/views src/utils

# ── 5. Configuration Firebase ─────────────────────────────────
cat > src/firebase/config.js << 'EOF'
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey:            "AIzaSyASeqLubTgHZxmzvCkNg7nwTFIZOh4sMCA",
  authDomain:        "chronotrack-8c563.firebaseapp.com",
  projectId:         "chronotrack-8c563",
  storageBucket:     "chronotrack-8c563.firebasestorage.app",
  messagingSenderId: "515465540862",
  appId:             "1:515465540862:web:1723c4fc0f87e04e87e1af",
  measurementId:     "G-9ZPXNQWL2J"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
EOF

# ── 6. Service Firebase ───────────────────────────────────────
cat > src/firebase/service.js << 'EOF'
import {
  collection, doc, setDoc, deleteDoc,
  getDocs, onSnapshot, serverTimestamp, query, orderBy
} from 'firebase/firestore';
import { db } from './config';

// ── Sessions ──────────────────────────────────────────────────
export const saveSess = (s) =>
  setDoc(doc(db, 'sessions', s.id), {
    name: s.name, date: s.date, defaultDist: s.defaultDist || null,
    createdAt: serverTimestamp()
  }, { merge: true });

export const deleteSess = (id) => deleteDoc(doc(db, 'sessions', id));

export const loadSessions = async () => {
  const snap = await getDocs(collection(db, 'sessions'));
  const sessions = [];
  for (const sd of snap.docs) {
    const d = sd.data();
    const sess = { id: sd.id, name: d.name, date: d.date || '', defaultDist: d.defaultDist || null, participants: [] };
    const pSnap = await getDocs(collection(db, 'sessions', sd.id, 'participants'));
    pSnap.forEach(pd => sess.participants.push({
      id: pd.id, name: pd.data().name, lastDist: pd.data().lastDist || null
    }));
    sessions.push(sess);
  }
  return sessions.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
};

export const watchSessions = (onChange) =>
  onSnapshot(collection(db, 'sessions'), onChange);

// ── Participants globaux ───────────────────────────────────────
export const saveGlobalP = (p) =>
  setDoc(doc(db, 'participants', p.id), { name: p.name }, { merge: true });

export const loadGlobalP = async () => {
  const snap = await getDocs(collection(db, 'participants'));
  return snap.docs.map(d => ({ id: d.id, name: d.data().name }));
};

export const saveSessP = (sid, p) =>
  setDoc(doc(db, 'sessions', sid, 'participants', p.id), {
    name: p.name, lastDist: p.lastDist || null
  }, { merge: true });

// ── Séries ────────────────────────────────────────────────────
export const saveSerie = (dateKey, serie) =>
  setDoc(doc(db, 'series', `${dateKey}_${serie.id}`), {
    dateKey, id: serie.id, dist: serie.dist,
    entries: serie.entries, createdAt: serverTimestamp()
  });

export const deleteSerie = (dateKey, id) =>
  deleteDoc(doc(db, 'series', `${dateKey}_${id}`));

export const loadSeries = async () => {
  const snap = await getDocs(collection(db, 'series'));
  const map = {};
  snap.forEach(d => {
    const dd = d.data();
    if (!map[dd.dateKey]) map[dd.dateKey] = [];
    map[dd.dateKey].push({ id: dd.id, dist: dd.dist, entries: dd.entries || [] });
  });
  return map;
};
EOF

# ── 7. Utilitaires ────────────────────────────────────────────
cat > src/utils/time.js << 'EOF'
export function fms(ms) {
  if (!ms || ms < 0) ms = 0;
  const m = Math.floor(ms / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  const c = Math.floor((ms % 1000) / 10);
  return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}.${String(c).padStart(2,'0')}`;
}

export function today() {
  return new Date().toISOString().split('T')[0];
}

export function fdate(iso) {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
  return `${parseInt(d)} ${months[parseInt(m)-1]} ${y}`;
}

export function extractDist(name) {
  const m = (name||'').match(/\d+x(\d+(?:\.\d+)?(?:m|km))/i)
         || (name||'').match(/(\d+(?:\.\d+)?(?:km|m))/i);
  return m ? m[1].toLowerCase() : null;
}

export function avgMs(arr) {
  return arr.length ? Math.round(arr.reduce((s,v) => s+v, 0) / arr.length) : null;
}
EOF

# ── 8. Hook useStore (état global) ───────────────────────────
cat > src/hooks/useStore.js << 'EOF'
import { useState, useEffect, useRef } from 'react';
import {
  loadSessions, loadGlobalP, loadSeries,
  saveSess, deleteSess, saveGlobalP, saveSessP,
  saveSerie, deleteSerie, watchSessions
} from '../firebase/service';

export function useStore() {
  const [sessions, setSessions]   = useState([]);
  const [globalP,  setGlobalP]    = useState([]);
  const [series,   setSeries]     = useState({});
  const [loading,  setLoading]    = useState(true);
  const firstSnap = useRef(true);

  // Chargement initial
  useEffect(() => {
    Promise.all([loadSessions(), loadGlobalP(), loadSeries()])
      .then(([s, p, sr]) => {
        setSessions(s);
        setGlobalP(p);
        setSeries(sr);
        setLoading(false);
      });
  }, []);

  // Listener temps réel sessions
  useEffect(() => {
    const unsub = watchSessions(snap => {
      if (firstSnap.current) { firstSnap.current = false; return; }
      setSessions(prev => {
        let next = [...prev];
        snap.docChanges().forEach(ch => {
          const id = ch.doc.id, d = ch.doc.data();
          if (ch.type === 'removed') {
            next = next.filter(s => s.id !== id);
          } else if (ch.type === 'modified') {
            const ex = next.find(s => s.id === id);
            if (ex) { ex.name = d.name; ex.date = d.date; ex.defaultDist = d.defaultDist || null; }
          } else if (ch.type === 'added') {
            if (!next.find(s => s.id === id)) {
              next.unshift({ id, name: d.name, date: d.date || '', defaultDist: d.defaultDist || null, participants: [] });
            }
          }
        });
        return next.sort((a,b) => (b.date||'').localeCompare(a.date||''));
      });
    });
    return () => unsub();
  }, []);

  // Actions sessions
  const createSession = async (s) => {
    setSessions(prev => [s, ...prev].sort((a,b) => (b.date||'').localeCompare(a.date||'')));
    await saveSess(s);
    for (const p of s.participants) await saveSessP(s.id, p);
    return s;
  };

  const deleteSession = async (id) => {
    setSessions(prev => prev.filter(s => s.id !== id));
    await deleteSess(id);
  };

  const deleteSessions = async (ids) => {
    setSessions(prev => prev.filter(s => !ids.includes(s.id)));
    await Promise.all(ids.map(id => deleteSess(id)));
  };

  // Actions participants globaux
  const addGlobalP = async (p) => {
    setGlobalP(prev => [...prev, p]);
    await saveGlobalP(p);
    return p;
  };

  // Actions participant dans session
  const addSessP = async (sessId, p) => {
    setSessions(prev => prev.map(s =>
      s.id === sessId ? { ...s, participants: [...s.participants, p] } : s
    ));
    await saveSessP(sessId, p);
    await saveGlobalP({ id: p.id, name: p.name });
    setGlobalP(prev => prev.find(x => x.id === p.id) ? prev : [...prev, { id: p.id, name: p.name }]);
  };

  // Actions séries
  const addSerie = async (dateKey, serie) => {
    setSeries(prev => ({
      ...prev,
      [dateKey]: [...(prev[dateKey] || []), serie]
    }));
    await saveSerie(dateKey, serie);
  };

  const removeSerie = async (dateKey, serieId) => {
    setSeries(prev => {
      const day = (prev[dateKey] || []).filter(s => s.id !== serieId);
      const next = { ...prev };
      if (day.length) next[dateKey] = day; else delete next[dateKey];
      return next;
    });
    await deleteSerie(dateKey, serieId);
  };

  const updateSerieEntry = async (dateKey, serieId, entryIdx, include) => {
    setSeries(prev => {
      const day = (prev[dateKey] || []).map(s => {
        if (s.id !== serieId) return s;
        const entries = s.entries.map((e, i) => i === entryIdx ? { ...e, include } : e);
        return { ...s, entries };
      });
      return { ...prev, [dateKey]: day };
    });
    const serie = series[dateKey]?.find(s => s.id === serieId);
    if (serie) {
      const updated = { ...serie, entries: serie.entries.map((e,i) => i === entryIdx ? { ...e, include } : e) };
      await saveSerie(dateKey, updated);
    }
  };

  const removeSeriesByDate = async (dateKey) => {
    const day = series[dateKey] || [];
    setSeries(prev => { const next = { ...prev }; delete next[dateKey]; return next; });
    await Promise.all(day.map(s => deleteSerie(dateKey, s.id)));
  };

  const removeSeriesByParticipant = async (dateKey, pid) => {
    const day = series[dateKey] || [];
    const toDelete = day.filter(s => s.entries.some(e => e.pid === pid));
    const toKeep   = day.filter(s => !s.entries.some(e => e.pid === pid));
    setSeries(prev => ({ ...prev, [dateKey]: toKeep }));
    await Promise.all(toDelete.map(s => deleteSerie(dateKey, s.id)));
  };

  return {
    sessions, globalP, series, loading,
    createSession, deleteSession, deleteSessions,
    addGlobalP, addSessP,
    addSerie, removeSerie, updateSerieEntry,
    removeSeriesByDate, removeSeriesByParticipant,
  };
}
EOF

# ── 9. App.jsx principal ──────────────────────────────────────
cat > src/App.jsx << 'EOF'
import { useState } from 'react';
import { useStore } from './hooks/useStore';
import SessionsView  from './views/SessionsView';
import ChronoView    from './views/ChronoView';
import CalendarView  from './views/CalendarView';
import ProgressView  from './views/ProgressView';
import './App.css';

export default function App() {
  const store = useStore();
  const [tab,     setTab]     = useState('sessions');
  const [curSess, setCurSess] = useState(null);

  const openSess = (s) => { setCurSess(s); setTab('chrono'); };
  const backToSess = () => { setCurSess(null); setTab('sessions'); };

  if (store.loading) return (
    <div style={{display:'flex',alignItems:'center',justifyContent:'center',height:'100vh',flexDirection:'column',gap:12}}>
      <div style={{fontSize:32}}>⏱</div>
      <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:20,fontWeight:700}}>ChronoTrack</div>
      <div style={{fontSize:13,color:'#7a8fa6'}}>Chargement...</div>
    </div>
  );

  return (
    <div className="app">
      <header className="hdr">
        <div className="hdr-logo">⏱</div>
        <div className="hdr-name">ChronoTrack</div>
        <div className="hdr-ver">v3.0.0</div>
        <div className="hdr-ble on">
          <div className="ble-dot pulse" />
          Firebase OK
        </div>
      </header>

      <main className="main">
        {tab === 'sessions' && <SessionsView store={store} onOpen={openSess} />}
        {tab === 'chrono'   && <ChronoView   store={store} sess={curSess} onBack={backToSess} />}
        {tab === 'calendar' && <CalendarView  store={store} />}
        {tab === 'prog'     && <ProgressView  store={store} />}
      </main>

      {tab !== 'chrono' && (
        <nav className="nav">
          {[
            { id:'sessions', ico:'📋', lbl:'Sessions' },
            { id:'calendar', ico:'📅', lbl:'Calendrier' },
            { id:'prog',     ico:'📈', lbl:'Progression' },
          ].map(n => (
            <button key={n.id} className={`nav-btn${tab===n.id?' on':''}`} onClick={()=>setTab(n.id)}>
              <div className="nav-bar" />
              <span className="ico">{n.ico}</span>
              <span className="lbl">{n.lbl}</span>
            </button>
          ))}
        </nav>
      )}
    </div>
  );
}
EOF

# ── 10. CSS Global ────────────────────────────────────────────
cat > src/App.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@600;700&family=DM+Mono:wght@400;500&family=DM+Sans:wght@400;500;600&display=swap');

:root {
  --bg:#f4f6f9; --card:#fff; --card2:#eef1f6;
  --blue:#0077b6; --bdim:rgba(0,119,182,.09);
  --green:#06a77d; --gdim:rgba(6,167,125,.1);
  --red:#d62839; --rdim:rgba(214,40,57,.09);
  --yellow:#e07a00; --ydim:rgba(224,122,0,.09);
  --text:#1a2535; --muted:#7a8fa6; --faint:#c5d0de;
  --border:rgba(0,0,0,.08);
}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
body{background:var(--bg);color:var(--text);font-family:'DM Sans',sans-serif;min-height:100vh}
.app{display:flex;flex-direction:column;min-height:100vh}
.main{flex:1;padding-bottom:82px}

/* Header */
.hdr{position:sticky;top:0;z-index:99;background:rgba(255,255,255,.96);backdrop-filter:blur(12px);
  border-bottom:1px solid var(--border);height:56px;display:flex;align-items:center;
  padding:0 16px;gap:10px;box-shadow:0 1px 6px rgba(0,0,0,.06)}
.hdr-logo{width:30px;height:30px;background:var(--bdim);border:1px solid var(--blue);
  border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:15px}
.hdr-name{flex:1;font-family:'Rajdhani',sans-serif;font-size:19px;font-weight:700}
.hdr-ver{font-family:'DM Mono',monospace;font-size:12px;font-weight:700;color:var(--blue);
  background:var(--bdim);border:1.5px solid var(--blue);padding:3px 9px;border-radius:7px}
.hdr-ble{display:flex;align-items:center;gap:5px;padding:4px 9px;border-radius:18px;
  border:1px solid;font-size:10px;font-weight:600;white-space:nowrap}
.hdr-ble.on{color:var(--blue);border-color:var(--blue);background:var(--bdim)}
.ble-dot{width:5px;height:5px;border-radius:50%;background:currentColor}
.ble-dot.pulse{animation:blink 1.4s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.25}}

/* Nav */
.nav{position:fixed;bottom:0;left:0;right:0;z-index:99;background:rgba(255,255,255,.97);
  backdrop-filter:blur(16px);border-top:1px solid var(--border);display:flex;padding:6px 0 18px}
.nav-btn{flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;
  border:none;background:transparent;cursor:pointer;font-family:'DM Sans',sans-serif;padding:4px}
.nav-btn .ico{font-size:21px;transition:transform .18s}
.nav-btn .lbl{font-size:10px;font-weight:500;color:var(--muted)}
.nav-btn.on .lbl{color:var(--blue);font-weight:600}
.nav-btn.on .ico{transform:scale(1.12)}
.nav-bar{width:20px;height:2px;border-radius:2px;background:var(--blue);margin:0 auto 2px;opacity:0}
.nav-btn.on .nav-bar{opacity:1}

/* Cards */
.card{background:var(--card);border:1px solid var(--border);border-radius:13px;
  box-shadow:0 1px 5px rgba(0,0,0,.05)}

/* Buttons */
.btn{padding:8px 14px;border-radius:9px;border:none;font-family:'DM Sans',sans-serif;
  font-size:13px;font-weight:500;cursor:pointer;display:inline-flex;align-items:center;gap:5px;white-space:nowrap}
.btn-blue{background:var(--blue);color:#fff}.btn-blue:active{opacity:.8}
.btn-red{background:var(--red);color:#fff}.btn-red:active{opacity:.8}
.btn-outline{background:var(--card2);border:1px solid var(--border);color:var(--muted)}
.btn-outline.on{background:var(--bdim);border-color:var(--blue);color:var(--blue)}

/* Input */
.inp{width:100%;background:var(--card2);border:1px solid rgba(0,0,0,.1);border-radius:9px;
  padding:11px 13px;color:var(--text);font-family:'DM Sans',sans-serif;font-size:15px;
  outline:none;transition:border-color .18s}
.inp:focus{border-color:var(--blue)}
.inp::placeholder{color:var(--muted)}

/* Modal */
.moverlay{position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.32);backdrop-filter:blur(7px);
  display:flex;align-items:flex-end;opacity:0;pointer-events:none;transition:opacity .22s}
.moverlay.on{opacity:1;pointer-events:all}
.modal{width:100%;background:var(--card);border-radius:18px 18px 0 0;padding:20px 20px 32px;
  transform:translateY(100%);transition:transform .28s cubic-bezier(.4,0,.2,1);
  box-shadow:0 -8px 28px rgba(0,0,0,.1);max-height:87vh;overflow-y:auto}
.moverlay.on .modal{transform:translateY(0)}
.modal h3{font-family:'Rajdhani',sans-serif;font-size:19px;font-weight:700;margin-bottom:15px}
.mlbl{font-size:11px;font-weight:600;color:var(--muted);margin-bottom:5px;display:block;
  text-transform:uppercase;letter-spacing:.5px}
.msec{margin-bottom:13px}
.mbtns{display:flex;gap:9px;margin-top:5px}
.mbtn{flex:1;padding:12px;border-radius:10px;border:1px solid;
  font-family:'DM Sans',sans-serif;font-size:14px;font-weight:500;cursor:pointer}
.mbtn.cancel{background:var(--card2);border-color:var(--border);color:var(--muted)}
.mbtn.ok{background:var(--blue);border-color:var(--blue);color:#fff}

/* Picker */
.picker{display:flex;flex-direction:column;gap:5px;max-height:195px;overflow-y:auto;margin-bottom:7px}
.pick-item{display:flex;align-items:center;gap:9px;padding:9px 11px;border-radius:9px;
  border:1px solid var(--border);background:var(--card2);cursor:pointer;user-select:none}
.pick-item.sel{background:#f0f7ff;border-color:var(--blue)}
.pick-av{width:27px;height:27px;border-radius:50%;background:var(--bdim);
  display:flex;align-items:center;justify-content:center;
  font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;color:var(--blue);flex-shrink:0}
.pick-nm{flex:1;font-size:14px;font-weight:500}
.pick-ck{width:17px;height:17px;border-radius:5px;flex-shrink:0;
  border:2px solid var(--faint);background:transparent;
  display:flex;align-items:center;justify-content:center;transition:all .18s}
.pick-item.sel .pick-ck{background:var(--blue);border-color:var(--blue)}
.pick-empty{font-size:13px;color:var(--muted);text-align:center;padding:11px 0}
.pick-add{display:flex;align-items:center;gap:7px;margin-top:5px}
.pick-add input{flex:1;background:var(--card2);border:1px solid var(--border);border-radius:8px;
  padding:8px 11px;color:var(--text);font-family:'DM Sans',sans-serif;font-size:13px;outline:none}
.pick-add input:focus{border-color:var(--blue)}
.pick-add input::placeholder{color:var(--muted)}
.pick-add-btn{padding:8px 12px;border-radius:8px;background:var(--bdim);
  border:1px solid rgba(0,119,182,.2);color:var(--blue);font-size:13px;font-weight:500;
  cursor:pointer;font-family:'DM Sans',sans-serif;white-space:nowrap}

/* Dist presets */
.dpresets{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:9px}
.dp{padding:5px 11px;border-radius:18px;border:1px solid var(--border);background:var(--card2);
  color:var(--muted);font-size:12px;font-weight:500;cursor:pointer;font-family:'DM Sans',sans-serif}
.dp.on{background:var(--bdim);border-color:var(--blue);color:var(--blue)}

/* Toast */
.toast-wrap{position:fixed;top:66px;left:50%;transform:translateX(-50%);z-index:400;pointer-events:none}
.toast{background:var(--text);border-radius:9px;padding:9px 15px;font-size:13px;color:#fff;
  white-space:nowrap;box-shadow:0 4px 14px rgba(0,0,0,.14);
  animation:toast-in .3s ease,toast-out .3s ease 2s forwards}
@keyframes toast-in{from{opacity:0;transform:translateY(-12px)}to{opacity:1;transform:translateY(0)}}
@keyframes toast-out{from{opacity:1}to{opacity:0}}

/* Empty */
.empty{display:flex;flex-direction:column;align-items:center;padding:55px 20px;gap:9px;text-align:center}
.empty .ei{font-size:46px}.empty .ep{font-size:14px;color:var(--muted);font-weight:500}
.empty .es{font-size:12px;color:var(--faint)}

/* Tags */
.tag{padding:2px 7px;border-radius:9px;background:var(--bdim);
  color:var(--blue);font-size:10px;font-weight:600;display:inline-flex}
.tag.g{background:var(--gdim);color:var(--green)}

/* Rep chips */
.rep-chip{flex-shrink:0;display:flex;flex-direction:column;align-items:center;gap:2px;
  background:var(--card);border:1px solid var(--border);border-radius:9px;padding:6px 11px;min-width:72px}
.rep-chip .rc-lbl{font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px}
.rep-chip .rc-val{font-family:'DM Mono',monospace;font-size:13px;font-weight:600;color:#0096c7}
.rep-chip.avg{background:var(--gdim);border-color:rgba(6,167,125,.25)}
.rep-chip.avg .rc-lbl{color:var(--green)}
.rep-chip.avg .rc-val{color:var(--green)}
EOF

# ── 11. Vues React ───────────────────────────────────────────
# SessionsView
cat > src/views/SessionsView.jsx << 'SESSIONS'
import { useState } from 'react';
import { today, fdate, extractDist } from '../utils/time';
import Toast from '../components/Toast';

const DPRESETS = ['25m','50m','100m','200m','400m','1km','5km','10km'];

export default function SessionsView({ store, onOpen }) {
  const { sessions, globalP, createSession, deleteSession, deleteSessions, addGlobalP } = store;
  const [modal, setModal]   = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [toast, setToast]   = useState(null);
  const [name, setName]     = useState('');
  const [dist, setDist]     = useState('');
  const [date, setDate]     = useState(today());
  const [pSel, setPSel]     = useState(new Set());
  const [newP,  setNewP]    = useState('');

  const showToast = (msg) => { setToast(msg); setTimeout(() => setToast(null), 2400); };

  const toggleSel = (id) => {
    setSelected(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  const handleCreate = async () => {
    if (!name.trim()) { showToast('Entre un nom'); return; }
    const defaultDist = dist.trim() || extractDist(name) || null;
    const s = {
      id: Date.now().toString(), name: name.trim(), date, defaultDist,
      participants: [...pSel].map(pid => {
        const gp = globalP.find(p => p.id === pid);
        return gp ? { id: gp.id, name: gp.name, lastDist: defaultDist } : null;
      }).filter(Boolean)
    };
    await createSession(s);
    setModal(false); setName(''); setDist(''); setDate(today()); setPSel(new Set());
    showToast(`"${s.name}" créée ✓`);
    onOpen(s);
  };

  const handleAddNewP = async () => {
    if (!newP.trim()) return;
    const p = { id: Date.now().toString(), name: newP.trim() };
    await addGlobalP(p);
    setPSel(prev => new Set([...prev, p.id]));
    setNewP('');
    showToast(`${p.name} créé ✓`);
  };

  const handleBulkDelete = async () => {
    if (!selected.size) { showToast('Sélectionne au moins une session'); return; }
    if (!window.confirm(`Supprimer ${selected.size} session(s) ?`)) return;
    const n = selected.size;
    await deleteSessions([...selected]);
    setSelected(new Set());
    showToast(`${n} session(s) supprimée(s) ✓`);
  };

  const handleDelete = async (id, sname) => {
    if (!window.confirm(`Supprimer "${sname}" ?`)) return;
    await deleteSession(id);
    showToast('Session supprimée ✓');
  };

  return (
    <div>
      {toast && <div className="toast-wrap"><div className="toast">{toast}</div></div>}

      {/* Header */}
      <div style={{padding:'14px 16px 8px',display:'flex',alignItems:'flex-start',justifyContent:'space-between',gap:8}}>
        <div>
          <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:22,fontWeight:700}}>Mes sessions</div>
          <div style={{fontSize:11,color:'var(--muted)',marginTop:2}}>{sessions.length} session(s)</div>
        </div>
        <button className="btn btn-blue" onClick={() => setModal(true)}>+ Nouvelle</button>
      </div>

      {/* Bulk bar */}
      {selected.size > 0 && (
        <div style={{margin:'0 16px 10px',padding:'9px 13px',background:'var(--bdim)',border:'1px solid var(--border)',borderRadius:10,display:'flex',alignItems:'center',gap:8}}>
          <span style={{flex:1,fontSize:13,fontWeight:600,color:'var(--blue)'}}>{selected.size} sélectionnée(s)</span>
          <button className="btn btn-outline" onClick={() => { setSelected(new Set(sessions.map(s=>s.id))); }}>Tout</button>
          <button className="btn btn-outline" onClick={() => setSelected(new Set())}>Aucun</button>
          <button className="btn btn-red" onClick={handleBulkDelete}>🗑 Supprimer</button>
        </div>
      )}

      {/* Liste */}
      <div style={{padding:'0 16px',display:'flex',flexDirection:'column',gap:9}}>
        {sessions.length === 0 ? (
          <div className="empty"><div className="ei">📋</div><div className="ep">Aucune session</div><div className="es">Crée ta première session</div></div>
        ) : sessions.map(s => {
          const isSel = selected.has(s.id);
          return (
            <div key={s.id} className="card" style={{display:'flex',alignItems:'stretch',transition:'border-color .18s,background .18s',borderColor:isSel?'var(--blue)':'var(--border)',background:isSel?'#f0f7ff':'var(--card)'}}>
              {/* Checkbox */}
              <div style={{width:46,display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',flexShrink:0,borderRight:'1px solid rgba(0,0,0,.06)'}} onClick={() => toggleSel(s.id)}>
                <div style={{width:22,height:22,borderRadius:6,border:`2px solid ${isSel?'var(--blue)':'var(--faint)'}`,background:isSel?'var(--blue)':'white',display:'flex',alignItems:'center',justifyContent:'center',transition:'all .18s'}}>
                  {isSel && <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2.5" width="12" height="12"><polyline points="1.5,6.5 4.5,9.5 10.5,2.5"/></svg>}
                </div>
              </div>
              {/* Body */}
              <div style={{flex:1,padding:'13px 14px',display:'flex',alignItems:'center',gap:11,cursor:'pointer',minWidth:0}} onClick={() => onOpen(s)}>
                <div style={{width:40,height:40,borderRadius:10,background:'var(--bdim)',border:'1px solid rgba(0,119,182,.18)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:18,flexShrink:0}}>🏃</div>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{fontSize:15,fontWeight:600,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{s.name}</div>
                  <div style={{fontSize:11,color:'var(--muted)',marginTop:3,display:'flex',alignItems:'center',gap:6,flexWrap:'wrap'}}>
                    📅 {fdate(s.date)}
                    <span className="tag">👥 {s.participants.length}</span>
                    {s.defaultDist && <span className="tag g">📏 {s.defaultDist}</span>}
                  </div>
                </div>
                <div style={{color:'var(--faint)',fontSize:20}}>›</div>
              </div>
              {/* Delete */}
              <button onClick={() => handleDelete(s.id, s.name)} style={{width:46,display:'flex',alignItems:'center',justifyContent:'center',background:'var(--rdim)',border:'none',borderLeft:'1px solid rgba(214,40,57,.12)',cursor:'pointer',fontSize:17,color:'var(--red)',flexShrink:0}}>🗑</button>
            </div>
          );
        })}
      </div>

      {/* Modal Nouvelle session */}
      <div className={`moverlay${modal?' on':''}`} onClick={e => { if(e.target===e.currentTarget) setModal(false); }}>
        <div className="modal">
          <h3>Nouvelle session</h3>
          <div className="msec">
            <label className="mlbl">Nom</label>
            <input className="inp" value={name} onChange={e => { setName(e.target.value); const d=extractDist(e.target.value); if(d) setDist(d); }} placeholder="Ex : 10x400m, 5x50m..." />
          </div>
          <div className="msec">
            <label className="mlbl">Distance par défaut</label>
            <div className="dpresets">{DPRESETS.map(d => <span key={d} className={`dp${dist===d?' on':''}`} onClick={() => setDist(d)}>{d}</span>)}</div>
            <input className="inp" value={dist} onChange={e => setDist(e.target.value)} placeholder="Ex : 400m..." />
          </div>
          <div className="msec">
            <label className="mlbl">Date</label>
            <input className="inp" type="date" value={date} onChange={e => setDate(e.target.value)} />
          </div>
          <div className="msec">
            <label className="mlbl">Participants</label>
            <div className="picker">
              {globalP.length === 0 ? <div className="pick-empty">Aucun — crée-en ci-dessous</div>
              : globalP.map(p => (
                <div key={p.id} className={`pick-item${pSel.has(p.id)?' sel':''}`} onClick={() => setPSel(prev => { const n=new Set(prev); n.has(p.id)?n.delete(p.id):n.add(p.id); return n; })}>
                  <div className="pick-av">{p.name[0].toUpperCase()}</div>
                  <div className="pick-nm">{p.name}</div>
                  <div className="pick-ck">{pSel.has(p.id) && <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2.5" width="10" height="10"><polyline points="1.5,6.5 4.5,9.5 10.5,2.5"/></svg>}</div>
                </div>
              ))}
            </div>
            <div className="pick-add">
              <input value={newP} onChange={e => setNewP(e.target.value)} onKeyDown={e => e.key==='Enter'&&handleAddNewP()} placeholder="Nouveau participant..." />
              <button className="pick-add-btn" onClick={handleAddNewP}>+ Créer</button>
            </div>
          </div>
          <div className="mbtns">
            <button className="mbtn cancel" onClick={() => setModal(false)}>Annuler</button>
            <button className="mbtn ok" onClick={handleCreate}>Créer ›</button>
          </div>
        </div>
      </div>
    </div>
  );
}
SESSIONS

# ChronoView
cat > src/views/ChronoView.jsx << 'CHRONO'
import { useState, useEffect, useRef, useCallback } from 'react';
import { fms, today, extractDist } from '../utils/time';
import { saveSerie } from '../firebase/service';

const DPRESETS = ['25m','50m','100m','200m','400m','1km','5km','10km'];

function initP(p, defaultDist) {
  return { ...p, elapsed:0, isRunning:false, startTime:null, laps:[], times:[], repLaps:[], isSelected:false, lastDist: p.lastDist || defaultDist };
}

export default function ChronoView({ store, sess, onBack }) {
  const { addSerie, removeSeriesByDate, removeSeriesByParticipant } = store;
  const [parts,    setParts]    = useState(() => sess.participants.map(p => initP(p, sess.defaultDist)));
  const [modal,    setModal]    = useState(false);
  const [distModal,setDistModal]= useState(false);
  const [addModal, setAddModal] = useState(false);
  const [distVal,  setDistVal]  = useState('');
  const [pendStop, setPendStop] = useState([]);
  const [newPName, setNewPName] = useState('');
  const [pSel,     setPSel]     = useState(new Set());
  const [toast,    setToast]    = useState(null);
  const [tick,     setTick]     = useState(0);
  const tickRef = useRef(null);

  const showToast = (msg) => { setToast(msg); setTimeout(() => setToast(null), 2400); };

  // Ticker pour rafraîchir les temps
  useEffect(() => {
    tickRef.current = setInterval(() => setTick(t => t+1), 50);
    return () => clearInterval(tickRef.current);
  }, []);

  const ct = (p) => p.isRunning && p.startTime ? p.elapsed + (Date.now() - p.startTime) : p.elapsed;
  const selected = parts.filter(p => p.isSelected);
  const running  = parts.filter(p => p.isRunning);
  const avgArr   = (arr) => arr.length ? Math.round(arr.reduce((s,v)=>s+v,0)/arr.length) : null;

  const doStart = () => {
    const t = Date.now();
    setParts(prev => prev.map(p => p.isSelected && !p.isRunning
      ? { ...p, isRunning:true, startTime:t, elapsed:0, laps:[] }
      : p));
    showToast('▶ Démarré');
  };

  const doStop = () => {
    const stopped = [];
    setParts(prev => prev.map(p => {
      if (!p.isSelected || !p.isRunning) return p;
      const t = ct(p);
      const newTimes = [...p.times, t];
      const newRepLaps = [...p.repLaps, [...p.laps]];
      stopped.push({ p: { ...p, times: newTimes }, t });
      return { ...p, elapsed:0, isRunning:false, startTime:null, laps:[], times:newTimes, repLaps:newRepLaps };
    }));
    if (!stopped.length) return;
    const dist = stopped[0].p.lastDist || sess.defaultDist || extractDist(sess.name) || null;
    if (dist) {
      saveSerieDirect(stopped, dist);
    } else {
      setPendStop(stopped);
      setDistVal('');
      setDistModal(true);
    }
  };

  const saveSerieDirect = async (stopped, dist) => {
    const dk = sess.date || today();
    const serie = { id: Date.now().toString(), dist, entries: stopped.map(({p,t}) => ({ pid:p.id, name:p.name, timeMs:t, include:true })) };
    await addSerie(dk, serie);
    setParts(prev => prev.map(p => { const s = stopped.find(x => x.p.id === p.id); return s ? { ...p, lastDist: dist } : p; }));
    showToast(`⏹ Rep ${stopped[0].p.times.length} — ${dist}`);
  };

  const confirmDist = () => {
    if (!distVal.trim()) { showToast('Entre une distance'); return; }
    saveSerieDirect(pendStop, distVal.trim());
    setDistModal(false); setPendStop([]);
  };

  const doLap = (id) => {
    setParts(prev => prev.map(p => {
      if (p.id !== id || !p.isRunning) return p;
      const tot = ct(p);
      const prev_total = p.laps.length ? p.laps[p.laps.length-1].total : 0;
      return { ...p, laps: [...p.laps, { lap: tot - prev_total, total: tot }] };
    }));
    showToast('🚩 Lap');
  };

  const doReset = async () => {
    setParts(prev => prev.map(p => ({ ...p, elapsed:0, isRunning:false, startTime:null, laps:[], times:[], repLaps:[] })));
    await removeSeriesByDate(sess.date || today());
    showToast('↺ Réinitialisé');
  };

  const doResetOne = async (id) => {
    setParts(prev => prev.map(p => p.id===id ? { ...p, elapsed:0, isRunning:false, startTime:null, laps:[], times:[], repLaps:[] } : p));
    await removeSeriesByParticipant(sess.date || today(), id);
  };

  const toggleSel = (id) => setParts(prev => prev.map(p => p.id===id ? { ...p, isSelected:!p.isSelected } : p));
  const selAll  = () => setParts(prev => prev.map(p => ({ ...p, isSelected:true })));
  const selNone = () => setParts(prev => prev.map(p => ({ ...p, isSelected:false })));

  const canStart = selected.some(p => !p.isRunning);
  const canStop  = selected.some(p => p.isRunning);

  return (
    <div>
      {toast && <div className="toast-wrap"><div className="toast">{toast}</div></div>}

      {/* Topbar */}
      <div style={{padding:'10px 16px',background:'var(--card)',borderBottom:'1px solid var(--border)',position:'sticky',top:56,zIndex:90,display:'flex',alignItems:'center',gap:10}}>
        <button className="btn btn-outline" onClick={onBack}>← Sessions</button>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:17,fontWeight:700,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{sess.name}</div>
          <div style={{fontSize:11,color:'var(--muted)'}}>📅 {sess.date}{sess.defaultDist?' · 📏 '+sess.defaultDist:''}</div>
        </div>
        <button onClick={() => setAddModal(true)} style={{width:35,height:35,borderRadius:'50%',background:'var(--blue)',border:'none',color:'#fff',fontSize:20,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 2px 9px rgba(0,119,182,.3)'}}>+</button>
      </div>

      {/* Sel bar */}
      <div style={{margin:'9px 16px 5px',display:'flex',alignItems:'center',gap:6}}>
        <span style={{flex:1,fontSize:12,color:'var(--muted)'}}>{selected.length}/{parts.length} sélectionné(s)</span>
        <button className="btn btn-outline" style={{fontSize:11,padding:'4px 10px'}} onClick={selAll}>Tous</button>
        <button className="btn btn-outline" style={{fontSize:11,padding:'4px 10px'}} onClick={selNone}>Aucun</button>
      </div>

      {/* Participants */}
      <div style={{padding:'0 16px',display:'flex',flexDirection:'column',gap:9,paddingBottom:140}}>
        {parts.length === 0 ? (
          <div className="empty"><div className="ei">👥</div><div className="ep">Appuie sur + pour ajouter</div></div>
        ) : parts.map(p => {
          const t = ct(p);
          const hasT = p.times.length > 0;
          const hasL = p.laps.length > 0;
          const showActs = p.isRunning || hasT || hasL;
          const chkStyle = {width:20,height:20,borderRadius:5,border:`2px solid ${p.isSelected?'var(--blue)':'var(--faint)'}`,background:p.isSelected?'var(--blue)':'white',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'all .18s'};

          return (
            <div key={p.id} className={`card${p.isRunning?' run':''}`} style={{borderColor:p.isSelected?'var(--blue)':p.isRunning?'rgba(0,119,182,.4)':'var(--border)',background:p.isSelected?'#f0f7ff':'var(--card)'}}>
              {/* Top row */}
              <div style={{padding:14,display:'flex',alignItems:'center',gap:11,cursor:'pointer'}} onClick={() => toggleSel(p.id)}>
                <div style={chkStyle}>{p.isSelected && <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2.5" width="11" height="11"><polyline points="1.5,6.5 4.5,9.5 10.5,2.5"/></svg>}</div>
                <div style={{width:37,height:37,borderRadius:'50%',border:`1.5px solid ${p.isRunning?'var(--blue)':'var(--faint)'}`,background:p.isRunning?'var(--bdim)':'var(--card2)',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'Rajdhani,sans-serif',fontSize:16,fontWeight:700,color:p.isRunning?'var(--blue)':'var(--muted)',flexShrink:0}}>{p.name[0].toUpperCase()}</div>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{fontSize:15,fontWeight:500}}>{p.name}</div>
                  <div style={{fontSize:11,color:'var(--muted)',marginTop:2,display:'flex',alignItems:'center',gap:4}}>
                    {p.isRunning ? <><div style={{width:5,height:5,borderRadius:'50%',background:'var(--blue)',animation:'blink 1.1s infinite'}} /> En cours · <span style={{fontSize:10,padding:'1px 6px',borderRadius:6,background:'var(--gdim)',color:'var(--green)',fontWeight:600}}>Rep {p.times.length+1}</span></>
                    : hasT ? <span style={{fontSize:10,padding:'1px 6px',borderRadius:6,background:'var(--gdim)',color:'var(--green)',fontWeight:600}}>{p.times.length} rep(s)</span>
                    : <span>En attente{p.lastDist?' · '+p.lastDist:''}</span>}
                  </div>
                </div>
                <div style={{fontFamily:'DM Mono,monospace',fontSize:22,fontWeight:500,color:p.isRunning?'var(--blue)':'var(--muted)',letterSpacing:1,flexShrink:0}}>{fms(t)}</div>
              </div>

              {/* Reps + laps */}
              {(hasT || (p.isRunning && hasL)) && (
                <div style={{padding:'4px 13px 6px',display:'flex',gap:8,overflowX:'auto',alignItems:'flex-start'}}>
                  {p.times.map((tv, i) => {
                    const rl = p.repLaps[i] || [];
                    return (
                      <div key={i} style={{flexShrink:0,display:'flex',flexDirection:'column',alignItems:'stretch',gap:3,minWidth:76}}>
                        <div className="rep-chip"><span className="rc-lbl">Rep {i+1}</span><span className="rc-val">{fms(tv)}</span></div>
                        {rl.map((l, li) => (
                          <div key={li} style={{background:'white',border:'1px solid var(--border)',borderRadius:7,padding:'3px 7px',textAlign:'center'}}>
                            <div style={{fontSize:9,fontWeight:700,color:'var(--muted)',textTransform:'uppercase'}}>Lap {li+1}</div>
                            <div style={{fontFamily:'DM Mono,monospace',fontSize:11,fontWeight:600,color:'var(--blue)'}}>{fms(l.lap)}</div>
                            <div style={{fontFamily:'DM Mono,monospace',fontSize:9,color:'var(--muted)'}}>@ {fms(l.total)}</div>
                          </div>
                        ))}
                      </div>
                    );
                  })}
                  {p.isRunning && p.laps.length > 0 && (
                    <div style={{flexShrink:0,display:'flex',flexDirection:'column',alignItems:'stretch',gap:3,minWidth:76}}>
                      <div className="rep-chip" style={{border:'1.5px dashed var(--blue)'}}><span className="rc-lbl">En cours</span></div>
                      {p.laps.map((l,li) => (
                        <div key={li} style={{background:'var(--bdim)',border:'1px solid rgba(0,119,182,.2)',borderRadius:7,padding:'3px 7px',textAlign:'center'}}>
                          <div style={{fontSize:9,fontWeight:700,color:'var(--blue)',textTransform:'uppercase'}}>Lap {li+1}</div>
                          <div style={{fontFamily:'DM Mono,monospace',fontSize:11,fontWeight:600,color:'var(--blue)'}}>{fms(l.lap)}</div>
                        </div>
                      ))}
                    </div>
                  )}
                  {p.times.length > 1 && (
                    <div style={{flexShrink:0,minWidth:76}}>
                      <div className="rep-chip avg"><span className="rc-lbl">Moy.</span><span className="rc-val">{fms(avgArr(p.times))}</span></div>
                    </div>
                  )}
                </div>
              )}

              {/* Actions */}
              {showActs && (
                <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'8px 13px',background:'var(--card2)',borderTop:'1px solid rgba(0,0,0,.05)'}}>
                  {p.isRunning
                    ? <button onClick={() => doLap(p.id)} style={{display:'flex',alignItems:'center',gap:5,padding:'6px 13px',borderRadius:8,background:'var(--bdim)',border:'1px solid var(--blue)',color:'var(--blue)',fontFamily:'DM Sans,sans-serif',fontSize:13,fontWeight:600,cursor:'pointer'}}>🚩 Lap</button>
                    : <span />}
                  <button onClick={() => doResetOne(p.id)} style={{fontSize:12,color:'var(--muted)',background:'none',border:'none',cursor:'pointer',padding:'4px 8px'}}>↺ Reset</button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* IoT Panel */}
      <div style={{position:'fixed',bottom:0,left:0,right:0,background:'rgba(255,255,255,.97)',backdropFilter:'blur(16px)',borderTop:'1px solid var(--border)',padding:'10px 15px 22px',zIndex:60,boxShadow:'0 -2px 10px rgba(0,0,0,.05)'}}>
        <div style={{fontSize:10,color:'var(--muted)',marginBottom:7}}>🔵 Synchronisation Firebase active</div>
        <div style={{display:'flex',gap:7}}>
          {[
            { label:'START', color:'var(--blue)', dimColor:'var(--bdim)', border:'rgba(0,119,182,.35)', disabled:!canStart, flex:3, onClick:doStart, icon:'▶' },
            { label:'STOP',  color:'var(--red)',  dimColor:'var(--rdim)', border:'rgba(214,40,57,.35)', disabled:!canStop,  flex:3, onClick:doStop,  icon:'⏹' },
            { label:'RESET', color:'var(--muted)',dimColor:'var(--card2)',border:'rgba(0,0,0,.1)',       disabled:false,     flex:2, onClick:doReset, icon:'↺' },
          ].map(b => (
            <button key={b.label} disabled={b.disabled} onClick={b.onClick}
              style={{flex:b.flex,border:`1.5px solid ${b.border}`,borderRadius:11,background:b.dimColor,cursor:b.disabled?'not-allowed':'pointer',padding:'9px 4px',display:'flex',flexDirection:'column',alignItems:'center',gap:2,opacity:b.disabled?.25:1,transition:'opacity .18s,transform .1s',fontFamily:'DM Sans,sans-serif'}}>
              <span style={{fontSize:17}}>{b.icon}</span>
              <span style={{fontSize:9,fontWeight:700,letterSpacing:.8,color:b.color}}>{b.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Modal distance */}
      <div className={`moverlay${distModal?' on':''}`}>
        <div className="modal">
          <h3>Quelle distance ?</h3>
          <div className="msec">
            <div className="dpresets">{DPRESETS.map(d => <span key={d} className={`dp${distVal===d?' on':''}`} onClick={() => setDistVal(d)}>{d}</span>)}</div>
            <input className="inp" value={distVal} onChange={e => setDistVal(e.target.value)} placeholder="Ex: 50m, 400m..." />
          </div>
          <div className="mbtns">
            <button className="mbtn cancel" onClick={() => setDistModal(false)}>Ignorer</button>
            <button className="mbtn ok" onClick={confirmDist}>Enregistrer ›</button>
          </div>
        </div>
      </div>
    </div>
  );
}
CHRONO

# CalendarView et ProgressView (stubs fonctionnels)
cat > src/views/CalendarView.jsx << 'CAL'
import { useState } from 'react';
import { fdate, today } from '../utils/time';
import { fms } from '../utils/time';

const MONTHS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
const DPRESETS = ['25m','50m','100m','200m','400m','1km','5km','10km'];

export default function CalendarView({ store }) {
  const { series, globalP, addSerie, updateSerieEntry } = store;
  const now = new Date();
  const [year,  setYear]  = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth());
  const [day,   setDay]   = useState(today());
  const [modal, setModal] = useState(false);
  const [dist,  setDist]  = useState('');
  const [inputs,setInputs]= useState({});
  const [toast, setToast] = useState(null);

  const showToast = msg => { setToast(msg); setTimeout(() => setToast(null), 2400); };

  const calPrev = () => { if(month===0){setMonth(11);setYear(y=>y-1);}else setMonth(m=>m-1); };
  const calNext = () => { if(month===11){setMonth(0);setYear(y=>y+1);}else setMonth(m=>m+1); };

  const firstDay = new Date(year, month, 1).getDay();
  const offset = firstDay === 0 ? 6 : firstDay - 1;
  const dim = new Date(year, month+1, 0).getDate();
  const todayStr = today();

  const handleAddSerie = async () => {
    if (!dist.trim()) { showToast('Entre une distance'); return; }
    const entries = globalP.map(p => ({ pid:p.id, name:p.name, timeMs: parseTime(inputs[p.id]||''), include:true })).filter(e => e.timeMs !== null);
    if (!entries.length) { showToast('Entre au moins un temps'); return; }
    const serie = { id: Date.now().toString(), dist: dist.trim(), entries };
    await addSerie(day, serie);
    setModal(false); setDist(''); setInputs({});
    showToast(`Série ${dist} enregistrée ✓`);
  };

  return (
    <div>
      {toast && <div className="toast-wrap"><div className="toast">{toast}</div></div>}
      <div style={{padding:'14px 16px 8px',display:'flex',alignItems:'flex-start',justifyContent:'space-between'}}>
        <div><div style={{fontFamily:'Rajdhani,sans-serif',fontSize:22,fontWeight:700}}>Calendrier</div><div style={{fontSize:11,color:'var(--muted)',marginTop:2}}>Jours verts = séries enregistrées</div></div>
      </div>
      <div style={{display:'flex',alignItems:'center',gap:10,padding:'0 16px 8px'}}>
        <button onClick={calPrev} style={{width:34,height:34,borderRadius:9,border:'1px solid var(--border)',background:'var(--card)',color:'var(--muted)',fontSize:17,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}}>‹</button>
        <div style={{flex:1,textAlign:'center',fontFamily:'Rajdhani,sans-serif',fontSize:20,fontWeight:700}}>{MONTHS[month]} {year}</div>
        <button onClick={calNext} style={{width:34,height:34,borderRadius:9,border:'1px solid var(--border)',background:'var(--card)',color:'var(--muted)',fontSize:17,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center'}}>›</button>
      </div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:2,padding:'0 11px'}}>
        {['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'].map(d => <div key={d} style={{textAlign:'center',fontSize:10,fontWeight:600,color:'var(--muted)',padding:'5px 0',textTransform:'uppercase'}}>{d}</div>)}
        {Array(offset).fill(null).map((_,i) => <div key={'e'+i} />)}
        {Array(dim).fill(null).map((_,i) => {
          const d = i+1;
          const iso = `${year}-${String(month+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
          const has = series[iso]?.length > 0;
          const isPicked = iso === day;
          const isToday = iso === todayStr;
          return (
            <div key={iso} onClick={() => setDay(iso)} style={{aspectRatio:1,borderRadius:9,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',cursor:'pointer',gap:2,
              background:isPicked?'var(--blue)':has?'rgba(6,167,125,.07)':isToday?'var(--bdim)':'transparent',
              border:isPicked?'2px solid var(--blue)':has?'1px solid rgba(6,167,125,.2)':isToday?'1.5px solid var(--blue)':'none'}}>
              <span style={{fontSize:14,fontWeight:isPicked||has?700:500,color:isPicked?'white':has?'var(--green)':isToday?'var(--blue)':'var(--text)',lineHeight:1}}>{d}</span>
              {has && <div style={{width:5,height:5,borderRadius:'50%',background:isPicked?'rgba(255,255,255,.7)':'var(--green)'}} />}
            </div>
          );
        })}
      </div>

      {/* Détail du jour */}
      {day && (
        <div style={{margin:'10px 16px',background:'var(--card)',border:'1px solid var(--border)',borderRadius:13,overflow:'hidden',boxShadow:'0 1px 5px rgba(0,0,0,.05)'}}>
          <div style={{padding:'11px 14px',display:'flex',alignItems:'center',justifyContent:'space-between',borderBottom:'1px solid rgba(0,0,0,.06)'}}>
            <div>
              <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:16,fontWeight:700}}>{fdate(day)}</div>
              <div style={{fontSize:11,color:'var(--muted)',marginTop:1}}>{series[day]?.length||0} série(s)</div>
            </div>
            <button className="btn btn-blue" style={{fontSize:12,padding:'7px 11px'}} onClick={() => setModal(true)}>+ Série</button>
          </div>
          <div style={{padding:'8px 14px',display:'flex',flexDirection:'column',gap:8}}>
            {(!series[day]||!series[day].length) ? <div style={{padding:'14px 0',textAlign:'center',fontSize:13,color:'var(--muted)'}}>Aucune série pour ce jour</div>
            : series[day].map((s,si) => {
              const inc = s.entries.filter(e=>e.include);
              const a = inc.length ? Math.round(inc.reduce((sum,e)=>sum+e.timeMs,0)/inc.length) : null;
              return (
                <div key={s.id} style={{background:'var(--card2)',borderRadius:10,padding:'10px 12px'}}>
                  <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:8}}>
                    <span style={{fontFamily:'Rajdhani,sans-serif',fontSize:15,fontWeight:700,color:'var(--blue)'}}>📏 {s.dist}</span>
                    {a !== null && <span style={{fontFamily:'DM Mono,monospace',fontSize:13,color:'var(--green)',fontWeight:500}}>Moy: {fms(a)}</span>}
                  </div>
                  <div style={{display:'flex',flexDirection:'column',gap:4}}>
                    {s.entries.map((e,ei) => (
                      <div key={ei} style={{display:'flex',alignItems:'center',gap:8,padding:'5px 8px',background:'white',borderRadius:8,border:'1px solid rgba(0,0,0,.06)'}}>
                        <div style={{width:24,height:24,borderRadius:'50%',background:'var(--bdim)',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'Rajdhani,sans-serif',fontSize:11,fontWeight:700,color:'var(--blue)',flexShrink:0}}>{e.name[0].toUpperCase()}</div>
                        <div style={{flex:1,fontSize:13,fontWeight:500}}>{e.name}</div>
                        <div style={{fontFamily:'DM Mono,monospace',fontSize:13}}>{fms(e.timeMs)}</div>
                        <button onClick={() => updateSerieEntry(day, s.id, ei, !e.include)} style={{width:28,height:28,borderRadius:7,border:`1.5px solid ${e.include?'var(--green)':'var(--faint)'}`,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',fontSize:13,background:e.include?'var(--gdim)':'transparent',color:e.include?'var(--green)':'var(--faint)',flexShrink:0}}>
                          {e.include?'✓':'✗'}
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Modal série */}
      <div className={`moverlay${modal?' on':''}`} onClick={e=>{if(e.target===e.currentTarget)setModal(false)}}>
        <div className="modal">
          <h3>Nouvelle série</h3>
          <div className="msec"><label className="mlbl">Distance</label><input className="inp" value={dist} onChange={e=>setDist(e.target.value)} placeholder="Ex: 50m, 100m..." /></div>
          <div className="msec">
            <label className="mlbl">Temps (MM:SS.cc)</label>
            {globalP.map(p => (
              <div key={p.id} style={{display:'flex',alignItems:'center',gap:8,padding:'7px 0',borderBottom:'1px solid rgba(0,0,0,.05)'}}>
                <div style={{width:27,height:27,borderRadius:'50%',background:'var(--bdim)',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'Rajdhani,sans-serif',fontSize:12,fontWeight:700,color:'var(--blue)',flexShrink:0}}>{p.name[0].toUpperCase()}</div>
                <div style={{flex:1,fontSize:13,fontWeight:500}}>{p.name}</div>
                <input style={{width:105,background:'var(--card2)',border:'1px solid rgba(0,0,0,.1)',borderRadius:8,padding:'7px 9px',color:'var(--text)',fontFamily:'DM Mono,monospace',fontSize:13,outline:'none',textAlign:'center'}} placeholder="MM:SS.cc" value={inputs[p.id]||''} onChange={e=>setInputs(prev=>({...prev,[p.id]:e.target.value}))} />
              </div>
            ))}
          </div>
          <div className="mbtns">
            <button className="mbtn cancel" onClick={()=>setModal(false)}>Annuler</button>
            <button className="mbtn ok" onClick={handleAddSerie}>Enregistrer ›</button>
          </div>
        </div>
      </div>
    </div>
  );
}

function parseTime(str) {
  str = (str||'').trim().replace(',','.');
  if (!str) return null;
  let ms = 0;
  if (str.includes(':')) { const [min,rest]=str.split(':'); ms+=parseInt(min)*60000; str=rest; }
  if (str.includes('.')) { const [s,cs]=str.split('.'); ms+=parseInt(s)*1000; ms+=parseInt((cs+'00').substring(0,2))*10; }
  else ms += parseInt(str)*1000;
  return isNaN(ms) ? null : ms;
}
CAL

cat > src/views/ProgressView.jsx << 'PROG'
import { fms, fdate } from '../utils/time';

const MONTHS_S = ['jan','fév','mar','avr','mai','juin','juil','août','sep','oct','nov','déc'];

export default function ProgressView({ store }) {
  const { series } = store;
  const [distFilter, setDistFilter] = window._progState || [null, ()=>{}];
  const [view, setView] = window._progViewState || ['s', ()=>{}];

  // Collect all distances
  const dists = [...new Set(Object.values(series).flatMap(d => d.map(s => s.dist)))].sort();

  // Collect data by person
  const byPerson = {};
  Object.entries(series).forEach(([dk, day]) => {
    day.forEach(s => {
      if (distFilter && distFilter !== 'Toutes' && s.dist !== distFilter) return;
      s.entries.filter(e => e.include).forEach(e => {
        const k = e.pid || e.name;
        if (!byPerson[k]) byPerson[k] = { name: e.name, data: [] };
        byPerson[k].data.push({ date: dk, dist: s.dist, timeMs: e.timeMs });
      });
    });
  });

  const avgMs = arr => arr.length ? Math.round(arr.reduce((s,v)=>s+v,0)/arr.length) : null;

  return (
    <div>
      <div style={{padding:'14px 16px 8px'}}>
        <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:22,fontWeight:700}}>Progression</div>
        <div style={{fontSize:11,color:'var(--muted)',marginTop:2}}>Moyenne par distance dans le temps</div>
      </div>

      {/* Filtres distances */}
      <div style={{padding:'8px 16px',display:'flex',gap:7,overflowX:'auto'}}>
        {['Toutes',...dists].map(d => (
          <span key={d} onClick={()=>setDistFilter(d==='Toutes'?null:d)}
            style={{padding:'6px 13px',borderRadius:18,border:'1px solid var(--border)',background:(!distFilter&&d==='Toutes')||distFilter===d?'var(--blue)':'var(--card)',color:(!distFilter&&d==='Toutes')||distFilter===d?'#fff':'var(--muted)',fontSize:12,fontWeight:500,cursor:'pointer',whiteSpace:'nowrap',flexShrink:0}}>
            {d}
          </span>
        ))}
      </div>

      {/* Moyenne globale */}
      {Object.keys(byPerson).length > 0 && (
        <div style={{margin:'0 16px 12px',background:'linear-gradient(135deg,var(--bdim),var(--gdim))',border:'1px solid var(--border)',borderRadius:13,padding:'13px 15px'}}>
          <div style={{fontFamily:'Rajdhani,sans-serif',fontSize:14,fontWeight:700,marginBottom:9}}>📊 Moyenne globale</div>
          {Object.values(byPerson).map(p => (
            <div key={p.name} style={{display:'flex',alignItems:'center',gap:9,marginBottom:6}}>
              <div style={{width:30,height:30,borderRadius:'50%',background:'var(--bdim)',border:'1.5px solid rgba(0,119,182,.2)',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'Rajdhani,sans-serif',fontSize:13,fontWeight:700,color:'var(--blue)',flexShrink:0}}>{p.name[0].toUpperCase()}</div>
              <div style={{flex:1,fontSize:13,fontWeight:500}}>{p.name}</div>
              <div style={{textAlign:'right'}}>
                <div style={{fontFamily:'DM Mono,monospace',fontSize:14,fontWeight:700,color:'var(--green)'}}>{fms(avgMs(p.data.map(d=>d.timeMs)))}</div>
                <div style={{fontSize:10,color:'var(--muted)'}}>{p.data.length} essai(s)</div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Toggle vue */}
      <div style={{display:'flex',gap:6,margin:'0 16px 10px'}}>
        {[['s','Par séance'],['m','Par mois']].map(([v,lbl]) => (
          <button key={v} onClick={()=>setView(v)}
            style={{flex:1,padding:7,borderRadius:8,border:'1px solid var(--border)',background:view===v?'var(--blue)':'var(--card2)',color:view===v?'#fff':'var(--muted)',fontFamily:'DM Sans,sans-serif',fontSize:12,fontWeight:500,cursor:'pointer'}}>
            {lbl}
          </button>
        ))}
      </div>

      {/* Contenu */}
      <div style={{padding:'0 16px 16px'}}>
        {!dists.length ? (
          <div className="empty"><div className="ei">📈</div><div className="ep">Aucune donnée</div><div className="es">Lance des chronos ou ajoute des séries dans le Calendrier</div></div>
        ) : Object.values(byPerson).map(person => {
          const distMap = {};
          person.data.forEach(d => { if(!distMap[d.dist])distMap[d.dist]=[]; distMap[d.dist].push(d); });
          return (
            <details key={person.name} open style={{background:'var(--card)',border:'1px solid var(--border)',borderRadius:13,overflow:'hidden',boxShadow:'0 1px 5px rgba(0,0,0,.05)',marginBottom:9}}>
              <summary style={{padding:'11px 13px',display:'flex',alignItems:'center',gap:9,cursor:'pointer',listStyle:'none'}}>
                <div style={{width:35,height:35,borderRadius:'50%',background:'var(--bdim)',border:'1.5px solid rgba(0,119,182,.22)',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'Rajdhani,sans-serif',fontSize:15,fontWeight:700,color:'var(--blue)',flexShrink:0}}>{person.name[0].toUpperCase()}</div>
                <div style={{flex:1,fontSize:15,fontWeight:600}}>{person.name}</div>
                <span style={{color:'var(--faint)',fontSize:18}}>›</span>
              </summary>
              <div style={{padding:'11px 13px'}}>
                {Object.entries(distMap).map(([dist, entries]) => {
                  const grouped = {};
                  entries.forEach(e => {
                    const k = view==='s' ? e.date : e.date.substring(0,7);
                    if(!grouped[k])grouped[k]=[];
                    grouped[k].push(e.timeMs);
                  });
                  let prev = null;
                  const rows = Object.entries(grouped).sort((a,b)=>a[0].localeCompare(b[0]));
                  return (
                    <div key={dist} style={{marginBottom:13}}>
                      <div style={{fontSize:11,fontWeight:600,color:'var(--blue)',textTransform:'uppercase',letterSpacing:.5,marginBottom:7}}>📏 {dist}</div>
                      <table style={{width:'100%',borderCollapse:'collapse'}}>
                        <thead><tr>{['Période','Moyenne','Essais','Évolution'].map(h=><th key={h} style={{fontSize:10,fontWeight:600,color:'var(--muted)',textTransform:'uppercase',letterSpacing:.5,padding:'4px 6px',textAlign:'left',borderBottom:'1px solid rgba(0,0,0,.06)'}}>{h}</th>)}</tr></thead>
                        <tbody>
                          {rows.map(([period, times]) => {
                            const a = Math.round(times.reduce((s,t)=>s+t,0)/times.length);
                            let delta = null;
                            if (prev !== null) { const diff=a-prev; delta={diff,better:diff<0}; }
                            prev = a;
                            const lbl = view==='s' ? fdate(period) : MONTHS_S[parseInt(period.split('-')[1])-1]+' '+period.split('-')[0];
                            return (
                              <tr key={period}>
                                <td style={{fontSize:12,padding:'6px 6px',borderBottom:'1px solid rgba(0,0,0,.04)'}}>{lbl}</td>
                                <td style={{fontSize:12,padding:'6px 6px',borderBottom:'1px solid rgba(0,0,0,.04)',fontFamily:'DM Mono,monospace',fontWeight:500}}>{fms(a)}</td>
                                <td style={{fontSize:12,padding:'6px 6px',borderBottom:'1px solid rgba(0,0,0,.04)'}}>{times.length}</td>
                                <td style={{fontSize:12,padding:'6px 6px',borderBottom:'1px solid rgba(0,0,0,.04)'}}>
                                  {delta && <span style={{fontSize:11,fontWeight:600,padding:'2px 6px',borderRadius:6,background:delta.better?'var(--gdim)':'var(--rdim)',color:delta.better?'var(--green)':'var(--red)'}}>{delta.better?'':'+' }{fms(Math.abs(delta.diff))}</span>}
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  );
                })}
              </div>
            </details>
          );
        })}
      </div>
    </div>
  );
}
PROG

# Fix ProgressView state
sed -i '' 's/window._progState || \[null, ()=>{}\]/useState(null)/g' src/views/ProgressView.jsx
sed -i '' 's/window._progViewState || \['"'"'s'"'"', ()=>{}\]/useState('"'"'s'"'"')/g' src/views/ProgressView.jsx
# Add useState import
sed -i '' '1s/^/import { useState } from '"'"'react'"'"';\n/' src/views/ProgressView.jsx

# ── 12. Vite config pour les fonts Google ────────────────────
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/ChronoTrack/',
})
EOF

# ── 13. npm run build test ────────────────────────────────────
echo ""
echo "🔨 Test de build..."
npm run build

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     ✅ Connected ChronoTrack React — Prêt !             ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║  Pour développer en local :                             ║"
echo "║  cd ~/chronotrack-react                                 ║"
echo "║  npm run dev                                            ║"
echo "║  → http://localhost:5173/ChronoTrack/                  ║"
echo "║                                                          ║"
echo "║  Pour déployer sur GitHub Pages :                       ║"
echo "║  npm run build                                          ║"
echo "║  cp -r dist/* ~/ton-repo/                              ║"
echo "║  git add . && git commit -m 'v3.0.0' && git push       ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
