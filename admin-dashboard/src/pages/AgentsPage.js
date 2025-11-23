// src/pages/AgentsPage.js
  import React, { useEffect, useState } from 'react';
  import { collection, onSnapshot, query, where, orderBy, doc, updateDoc } from 'firebase/firestore';
  import { db, createAgentCallable } from '../firebase';

  export default function AgentsPage() {
    const [agents, setAgents] = useState([]);
    const [showAdd, setShowAdd] = useState(false);

    useEffect(() => {
      const q = query(collection(db, 'users'), where('role', '==', 'agent'), orderBy('createdAt', 'desc'));
      const unsub = onSnapshot(q, (snap) => {
        setAgents(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      });
      return () => unsub();
    }, []);

    const openAdd = () => setShowAdd(true);
    const closeAdd = () => setShowAdd(false);

    const onCreate = async (payload) => {
      // Call Cloud Function to create agent (secure)
      try {
        await createAgentCallable(payload);
        alert('Agent creation requested. Check logs for result.');
        closeAdd();
      } catch (e) {
        console.error(e);
        alert('Failed to create agent. Make sure Cloud Function is deployed.');
      }
    };

    const toggleActive = async (agent) => {
      try {
        await updateDoc(doc(db, 'users', agent.id), { active: !agent.active });
        alert('Updated.');
      } catch (e) {
        console.error(e);
        alert('Failed to update agent state.');
      }
    };

    return (
      <div className="page">
        <h2>Agents Management</h2>
        <div className="toolbar">
          <button className="btn" onClick={openAdd}>Add Agent</button>
        </div>

        <div className="list">
          {agents.map(a => (
            <div key={a.id} className="list-item">
              <div>
                <strong>{a.name || a.email}</strong>
                <div className="muted">{a.phone || '—'} · {a.staffId || '—'}</div>
              </div>
              <div className="actions">
                <button className="btn" onClick={()=>toggleActive(a)}>{a.active ? 'Deactivate' : 'Activate'}</button>
                <button className="btn-ghost" onClick={()=>alert('Edit modal placeholder')}>Edit</button>
                <button className="btn-ghost" onClick={()=>alert('Reset password via Cloud Function')}>Reset Password</button>
              </div>
            </div>
          ))}
          {agents.length === 0 && <div className="empty">No agents found.</div>}
        </div>

        {showAdd && <AddAgentModal onClose={closeAdd} onCreate={onCreate} />}
      </div>
    );
  }

  function AddAgentModal({ onClose, onCreate }) {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [name, setName] = useState('');
    const [phone, setPhone] = useState('');
    const [staffId, setStaffId] = useState('');
    const [region, setRegion] = useState('');

    const submit = () => {
      if (!email || !password) return alert('Email & password required.');
      onCreate({ email, password, name, phone, staffId, region });
    };

    return (
      <div className="modal">
        <h3>Create Agent</h3>
        <input placeholder="Full name" value={name} onChange={e=>setName(e.target.value)} />
        <input placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} />
        <input placeholder="Password" value={password} type="password" onChange={e=>setPassword(e.target.value)} />
        <input placeholder="Phone" value={phone} onChange={e=>setPhone(e.target.value)} />
        <input placeholder="Staff ID" value={staffId} onChange={e=>setStaffId(e.target.value)} />
        <input placeholder="Region / Assigned kiosks" value={region} onChange={e=>setRegion(e.target.value)} />
        <div className="modal-actions">
          <button className="btn" onClick={submit}>Create</button>
          <button className="btn-ghost" onClick={onClose}>Cancel</button>
        </div>
      </div>
    );
  }