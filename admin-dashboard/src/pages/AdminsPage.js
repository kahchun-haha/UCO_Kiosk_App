import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, where, orderBy } from 'firebase/firestore';
import { db, createAdminCallable } from '../firebase';

export default function AdminsPage() {
  const [admins, setAdmins] = useState([]);
  const [showAdd, setShowAdd] = useState(false);

  useEffect(() => {
    const q = query(collection(db, 'users'), where('role', 'in', ['admin', 'superadmin']), orderBy('createdAt', 'desc'));
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
      alert('Failed.');
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-text-main">Admin Access</h2>
          <p className="text-text-sub text-sm">Manage system administrators (Super Admin Only)</p>
        </div>
        <button 
          onClick={() => setShowAdd(true)} 
          className="bg-dark text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-dark-light shadow-lg shadow-dark/20 transition-all"
        >
          Add Admin
        </button>
      </div>

      <div className="flex flex-col gap-4">
        {admins.map(a => (
          <div key={a.id} className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-dark/5 text-dark rounded-xl flex items-center justify-center text-2xl">
                {a.role === 'superadmin' ? '🔑' : '👔'}
              </div>
              <div>
                <h3 className="font-bold text-text-main">{a.name || 'Unknown Admin'}</h3>
                <div className="flex gap-2 text-sm text-text-sub">
                  <span>{a.email}</span>
                  <span className="bg-gray-100 px-2 rounded text-xs font-mono uppercase flex items-center">{a.role}</span>
                </div>
              </div>
            </div>
            <div className="text-xs text-gray-400 italic">
              Managed in Console
            </div>
          </div>
        ))}
      </div>

      {showAdd && <AddAdminModal onClose={() => setShowAdd(false)} onCreate={onCreate} />}
    </div>
  );
}

function AddAdminModal({ onClose, onCreate }) {
  const [form, setForm] = useState({ email: '', password: '', name: '' });
  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const submit = () => {
    if (!form.email || !form.password) return alert('Required fields missing.');
    onCreate({ ...form, role: 'admin' });
  };

  const inputClass = "w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-dark/20 bg-gray-50 text-sm mb-3";

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4 z-50">
      <div className="bg-white p-6 rounded-2xl w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-xl text-text-main mb-4">Create New Admin</h3>
        <input name="name" placeholder="Full Name" className={inputClass} onChange={handleChange} />
        <input name="email" placeholder="Email" className={inputClass} onChange={handleChange} />
        <input name="password" type="password" placeholder="Password" className={inputClass} onChange={handleChange} />
        
        <div className="flex justify-end gap-3 mt-4">
          <button className="px-4 py-2 rounded-xl text-text-sub hover:bg-gray-50" onClick={onClose}>Cancel</button>
          <button className="px-4 py-2 rounded-xl bg-dark text-white shadow-lg shadow-dark/20" onClick={submit}>Request Create</button>
        </div>
      </div>
    </div>
  );
}