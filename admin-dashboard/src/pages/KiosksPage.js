// src/pages/KiosksPage.js
  import React, { useEffect, useState } from 'react';
  import { collection, onSnapshot } from 'firebase/firestore';
  import { db } from '../firebase';

  export default function KiosksPage() {
    const [kiosks, setKiosks] = useState([]);
    useEffect(() => {
      const unsub = onSnapshot(collection(db, 'kiosks'), (snap) => {
        setKiosks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      });
      return () => unsub();
    }, []);

    return (
      <div className="page">
        <h2>Kiosk Status</h2>
        <div className="grid">
          {kiosks.map(k => {
            const fill = k.fillLevel || 0;
            const state = fill > 80 ? 'red' : fill > 50 ? 'yellow' : 'green';
            return (
              <div key={k.id} className="kiosk-card">
                <div className="kiosk-top">
                  <strong>{k.location || k.id}</strong>
                  <span className={`badge ${state}`}>{fill}%</span>
                </div>
                <div className="muted">Last collected: {k.lastCollected ? new Date(k.lastCollected.seconds*1000).toLocaleString() : '—'}</div>
                <div className="muted">Assigned agent: {k.assignedAgent || '—'}</div>
              </div>
            );
          })}
          {kiosks.length === 0 && <div className="empty">No kiosks found.</div>}
        </div>
      </div>
    );
  }