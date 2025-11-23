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

  const onCreate = async (payload) => {
    try {
      await createAgentCallable(payload);
      alert('Agent creation requested.');
      setShowAdd(false);
    } catch (e) {
      console.error(e);
      alert('Failed to create agent.');
    }
  };

  const toggleActive = async (agent) => {
    try {
      await updateDoc(doc(db, 'users', agent.id), { active: !agent.active });
    } catch (e) {
      console.error(e);
      alert('Failed to update.');
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-text-main">Agents Management</h2>
          <p className="text-text-sub text-sm">Manage field staff and collectors</p>
        </div>
        <button 
          onClick={() => setShowAdd(true)} 
          className="bg-dark text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-dark-light shadow-lg shadow-dark/20 transition-all flex items-center gap-2"
        >
          <span>+</span> Add Agent
        </button>
      </div>

      <div className="flex flex-col gap-4">
        {agents.map(a => (
          <div key={a.id} className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 flex flex-col lg:flex-row justify-between items-center gap-4">
            <div className="flex items-center gap-4 w-full lg:w-auto">
              <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl ${a.active ? 'bg-blue-50 text-blue-500' : 'bg-gray-100 text-gray-400'}`}>
                🛡️
              </div>
              <div>
                <h3 className="font-bold text-text-main">{a.name || 'Unnamed Agent'}</h3>
                <div className="flex items-center gap-3 text-sm text-text-sub">
                  <span>{a.email}</span>
                  <span>•</span>
                  <span className="font-mono bg-gray-100 px-2 py-0.5 rounded text-xs">{a.staffId || 'NO ID'}</span>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3 w-full lg:w-auto border-t lg:border-none pt-4 lg:pt-0 border-gray-100">
              <button 
                onClick={() => toggleActive(a)}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${a.active ? 'bg-red-50 text-red-500 hover:bg-red-100' : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-100'}`}
              >
                {a.active ? 'Deactivate' : 'Activate'}
              </button>
              <button className="px-4 py-2 rounded-lg text-sm font-medium text-text-sub hover:bg-gray-100 border border-transparent hover:border-gray-200">
                Edit
              </button>
            </div>
          </div>
        ))}
        
        {agents.length === 0 && <div className="text-center py-12 text-text-sub">No agents found.</div>}
      </div>

      {showAdd && <AddAgentModal onClose={() => setShowAdd(false)} onCreate={onCreate} />}
    </div>
  );
}

function AddAgentModal({ onClose, onCreate }) {
  const [form, setForm] = useState({ email: '', password: '', name: '', phone: '', staffId: '', region: '' });

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const submit = () => {
    if (!form.email || !form.password) return alert('Email & password required.');
    onCreate(form);
  };

  // Reusable input style
  const inputClass = "w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 bg-gray-50 text-sm";

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4 z-50">
      <div className="bg-white p-6 rounded-2xl w-full max-w-lg shadow-2xl animate-in fade-in zoom-in duration-200">
        <div className="flex justify-between items-center mb-6">
          <h3 className="font-bold text-xl text-text-main">Create New Agent</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-dark">✕</button>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div className="col-span-2">
            <input name="name" placeholder="Full Name" className={inputClass} onChange={handleChange} />
          </div>
          <input name="email" placeholder="Email Address" className={inputClass} onChange={handleChange} />
          <input name="password" type="password" placeholder="Password" className={inputClass} onChange={handleChange} />
          <input name="phone" placeholder="Phone Number" className={inputClass} onChange={handleChange} />
          <input name="staffId" placeholder="Staff ID" className={inputClass} onChange={handleChange} />
          <div className="col-span-2">
            <input name="region" placeholder="Assigned Region / Kiosks" className={inputClass} onChange={handleChange} />
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
          <button className="px-5 py-2.5 rounded-xl text-text-sub hover:bg-gray-50 font-medium" onClick={onClose}>Cancel</button>
          <button className="px-5 py-2.5 rounded-xl bg-dark text-white font-medium hover:bg-dark-light shadow-lg shadow-dark/20" onClick={submit}>Create Agent</button>
        </div>
      </div>
    </div>
  );
}