// src/pages/UsersPage.js
  import React, { useEffect, useState } from 'react';
  import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
  import { db } from '../firebase';

  export default function UsersPage() {
    const [users, setUsers] = useState([]);
    useEffect(() => {
      const q = query(collection(db, 'users'), orderBy('createdAt', 'desc'));
      const unsub = onSnapshot(q, (snap) => {
        setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      });
      return () => unsub();
    }, []);

    return (
      <div className="page">
        <h2>Registered Users (View Only)</h2>
        <p>Normal users cannot be promoted/demoted in this panel.</p>
        <div className="list">
          {users.map(u => (
            <div key={u.id} className="list-item">
              <div>
                <strong>{u.email}</strong>
                <div className="muted">{u.name || '—'} &middot; Registered: {u.createdAt ? new Date(u.createdAt.seconds*1000).toLocaleDateString() : '—'}</div>
              </div>
              <div className="stats">
                <div>Deposits: {u.depositCount || 0}</div>
                <div>Volume: {u.totalVolume || 0} L</div>
              </div>
            </div>
          ))}
          {users.length === 0 && <div className="empty">No users found.</div>}
        </div>
      </div>
    );
  }