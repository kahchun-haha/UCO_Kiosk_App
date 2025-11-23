import React, { useState } from 'react';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '../firebase';

export default function Login(){
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error,setError] = useState('');
  const [loading,setLoading] = useState(false);
  const [showForgot, setShowForgot] = useState(false);
  const [resetEmail, setResetEmail] = useState('');
  const [resetMsg, setResetMsg] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (e) {
      console.error(e);
      setError('Invalid credentials or user not found.');
    } finally {
      setLoading(false);
    }
  };

  const sendReset = async () => {
    if(!resetEmail) return setResetMsg('Enter an email.');
    try {
      await sendPasswordResetEmail(auth, resetEmail);
      setResetMsg('Password reset email sent.');
    } catch(e){
      console.error(e);
      setResetMsg('Failed to send reset email.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-slate-100 to-white">
      <div className="w-full max-w-md bg-white p-8 rounded-xl shadow">
        <h1 className="text-2xl font-semibold">UMinyak Admin</h1>
        <p className="text-sm text-slate-500 mb-4">Sign in to access the admin dashboard</p>

        <form onSubmit={submit} className="space-y-3">
          <input required type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email" className="w-full border px-3 py-2 rounded" />
          <input required type="password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Password" className="w-full border px-3 py-2 rounded" />
          {error && <div className="text-red-600 text-sm">{error}</div>}
          <div className="flex items-center justify-between">
            <button className="bg-sky-600 text-white px-4 py-2 rounded" disabled={loading}>{loading ? 'Signing...' : 'Sign In'}</button>
            <button type="button" className="text-slate-500 text-sm" onClick={()=>setShowForgot(true)}>Forgot password?</button>
          </div>
        </form>
      </div>

      {showForgot && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/40">
          <div className="bg-white p-6 rounded-md w-full max-w-sm">
            <h3 className="font-semibold mb-2">Reset Password</h3>
            <input type="email" className="w-full border px-3 py-2 rounded" placeholder="Email" value={resetEmail} onChange={e=>setResetEmail(e.target.value)} />
            <div className="mt-3 flex justify-end gap-2">
              <button className="px-3 py-1 rounded border" onClick={()=>setShowForgot(false)}>Cancel</button>
              <button className="px-3 py-1 rounded bg-emerald-500 text-white" onClick={sendReset}>Send reset email</button>
            </div>
            {resetMsg && <div className="mt-2 text-sm text-slate-600">{resetMsg}</div>}
          </div>
        </div>
      )}
    </div>
  );
}
