// src/pages/AdminsPage.js
  import React, { useEffect, useState } from 'react';
  import { collection, onSnapshot, query, where, orderBy } from 'firebase/firestore';
  import { db, createAdminCallable } from '../firebase';

  export default function AdminsPage() {
    const [admins, setAdmins] = useState([]);
    const [showAdd, setShowAdd] = useState(false);

    useEffect(() => {
      const q = query(collection(db, 'users'), where('role', 'in', ['admin','superadmin']), orderBy('createdAt','desc'));
      const unsub = onSnapshot(q, (snap) => {
        setAdmins(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      });
      return () => unsub();
    }, []);

    const onCreate = async (payload) => {
      try {
        await createAdminCallable(payload);
        alert('Admin creation requested.');
        setShowAdd(false);
      } catch (e) {
        console.error(e);
        alert('Failed to request admin creation.');
      }
    };

    return (
      <div className="page">
        <h2>Admins (super-admin only)</h2>
        <p>Only super-admin can add other admins.</p>
        <div className="toolbar">
          <button className="btn" onClick={()=>setShowAdd(true)}>Add Admin</button>
        </div>

        <div className="list">
          {admins.map(a => (
            <div key={a.id} className="list-item">
              <div>
                <strong>{a.name || a.email}</strong>
                <div className="muted">{a.role}</div>
              </div>
              <div className="actions">
                <div className="muted">No downgrade or delete in UI</div>
              </div>
            </div>
          ))}
          {admins.length === 0 && <div className="empty">No admins found.</div>}
        </div>

        {showAdd && <AddAdminModal onClose={()=>setShowAdd(false)} onCreate={onCreate} />}
      </div>
    );
  }

  function AddAdminModal({ onClose, onCreate }) {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [name, setName] = useState('');

    const submit = () => {
      if (!email || !password) return alert('Email & password required.');
      onCreate({ email, password, name, role: 'admin' });
    };

    return (
      <div className="modal">
        <h3>Create Admin (super-admin only)</h3>
        <input placeholder="Full name" value={name} onChange={e=>setName(e.target.value)} />
        <input placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} />
        <input placeholder="Password" value={password} type="password" onChange={e=>setPassword(e.target.value)} />
        <div className="modal-actions">
          <button className="btn" onClick={submit}>Request Create</button>
          <button className="btn-ghost" onClick={onClose}>Cancel</button>
        </div>
      </div>
    );
  }