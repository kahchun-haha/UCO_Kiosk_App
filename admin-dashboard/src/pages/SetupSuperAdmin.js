import React, { useState } from 'react';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { auth, db } from '../firebase';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';

export default function SetupSuperAdmin({ onCreated }){
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    if(!email || !password) return alert('Email & password required.');
    setLoading(true);
    try {
      const userCred = await createUserWithEmailAndPassword(auth, email, password);
      const uid = userCred.user.uid;
      await setDoc(doc(db, 'users', uid), {
        email,
        name,
        role: 'superadmin',
        createdAt: serverTimestamp()
      });
      alert('Superadmin created. You may sign in now.');
      await auth.signOut();
      onCreated && onCreated();
    } catch (e) {
      console.error(e);
      alert('Failed to create superadmin: ' + e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-slate-100 to-white">
      <div className="w-full max-w-md bg-white p-8 rounded-xl shadow">
        <h2 className="text-2xl font-semibold mb-4">First-time setup — Create Superadmin</h2>
        <p className="text-sm text-slate-500 mb-4">This is a one-time setup. The superadmin is the only account that can create other admins.</p>
        <form onSubmit={submit} className="space-y-3">
          <input className="w-full border rounded px-3 py-2" value={name} onChange={e=>setName(e.target.value)} placeholder="Full name" />
          <input className="w-full border rounded px-3 py-2" value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email" type="email" />
          <input className="w-full border rounded px-3 py-2" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Password" type="password" />
          <div className="flex justify-end">
            <button className="bg-blue-600 text-white px-4 py-2 rounded" disabled={loading}>{loading ? 'Creating...' : 'Create Superadmin'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}
