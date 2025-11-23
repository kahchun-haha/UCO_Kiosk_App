import React, { useState } from 'react';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '../firebase';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
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
    if (!resetEmail) return setResetMsg('Enter an email.');
    try {
      await sendPasswordResetEmail(auth, resetEmail);
      setResetMsg('Password reset email sent.');
    } catch (e) {
      console.error(e);
      setResetMsg('Failed to send reset email.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4">
      <div className="w-full max-w-md bg-white p-8 rounded-2xl shadow-sm border border-gray-100">
        
        {/* HEADER SECTION */}
        <div className="mb-8">
          {/* Logo Row: Icon + App Name side-by-side */}
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center text-2xl text-primary">
              ♻️
            </div>
            <span className="text-2xl font-bold text-primary tracking-tight">
              UMinyak
            </span>
          </div>
          
          {/* Greeting Text */}
          <h1 className="text-2xl font-bold text-text-main">Welcome back</h1>
          <p className="text-text-sub mt-1">Sign in to your admin account</p>
        </div>

        <form onSubmit={submit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-text-main mb-1">Email</label>
            <input 
              required 
              type="email" 
              value={email} 
              onChange={e => setEmail(e.target.value)} 
              className="w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 bg-gray-50" 
              placeholder="admin@uminyak.com"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-text-main mb-1">Password</label>
            <input 
              required 
              type="password" 
              value={password} 
              onChange={e => setPassword(e.target.value)} 
              className="w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 bg-gray-50" 
              placeholder="••••••••" 
            />
          </div>

          {error && <div className="p-3 bg-red-50 text-red-500 text-sm rounded-xl">{error}</div>}

          <div className="pt-2">
            <button 
              className="w-full bg-dark text-white py-3.5 rounded-xl font-semibold hover:bg-dark-light transition-all shadow-lg shadow-dark/20 disabled:opacity-70" 
              disabled={loading}
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </div>
          
          <div className="text-center">
            <button type="button" className="text-sm text-text-sub hover:text-dark transition-colors" onClick={() => setShowForgot(true)}>
              Forgot password?
            </button>
          </div>
        </form>
      </div>

      {/* Forgot Password Modal */}
      {showForgot && (
        <div className="fixed inset-0 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4 z-50">
          <div className="bg-white p-6 rounded-2xl w-full max-w-sm shadow-xl animate-in fade-in zoom-in duration-200">
            <h3 className="font-bold text-lg text-text-main mb-2">Reset Password</h3>
            <p className="text-sm text-text-sub mb-4">Enter your email to receive a reset link.</p>
            <input 
              type="email" 
              className="w-full border border-gray-200 px-4 py-3 rounded-xl mb-4 bg-gray-50" 
              placeholder="Email" 
              value={resetEmail} 
              onChange={e => setResetEmail(e.target.value)} 
            />
            
            {resetMsg && <div className="mb-4 text-sm text-primary font-medium">{resetMsg}</div>}
            
            <div className="flex justify-end gap-3">
              <button className="px-4 py-2 rounded-xl text-text-sub hover:bg-gray-100 font-medium" onClick={() => setShowForgot(false)}>Cancel</button>
              <button className="px-4 py-2 rounded-xl bg-primary text-white font-medium hover:bg-opacity-90" onClick={sendReset}>Send Email</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}