import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, where, orderBy } from 'firebase/firestore';
import { db, createAdminCallable, deleteUserCallable, auth } from '../firebase';

export default function AdminsPage() {
  const [admins, setAdmins] = useState([]);
  const [showAdd, setShowAdd] = useState(false);

  // processing: null | "create" | "delete:<uid>"
  const [processing, setProcessing] = useState(null);

  useEffect(() => {
    const q = query(
      collection(db, 'users'),
      where('role', 'in', ['admin', 'superadmin']),
      orderBy('createdAt', 'desc')
    );

    const unsub = onSnapshot(q, (snap) => {
      setAdmins(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    });

    return () => unsub();
  }, []);

  const currentUserUid = auth.currentUser?.uid;
  const isCreating = processing === 'create';
  const isDeletingId = (id) => processing === `delete:${id}`;

  const onCreate = async (payload) => {
    if (isCreating) return;

    setProcessing('create');
    try {
      await createAdminCallable(payload);
      alert('Admin created successfully.');
      setShowAdd(false);
    } catch (e) {
      console.error(e);
      alert('Failed to create admin: ' + (e.message || 'Unknown error'));
    } finally {
      setProcessing(null);
    }
  };

  const handleDelete = async (adminId, adminName) => {
    if (
      !window.confirm(
        `Are you sure you want to permanently DELETE admin "${adminName || 'Unknown'}"? This cannot be undone.`
      )
    )
      return;

    setProcessing(`delete:${adminId}`);
    try {
      await deleteUserCallable({ targetUid: adminId });
      alert('Admin deleted successfully.');
    } catch (e) {
      console.error(e);
      alert('Failed to delete admin: ' + (e.message || 'Unknown error'));
    } finally {
      setProcessing(null);
    }
  };

  return (
    <div>
      {/* HEADER */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">Admin Access</h2>
          <p className="text-text-sub text-sm mt-2">Manage system administrators</p>
        </div>

        <button
          onClick={() => setShowAdd(true)}
          disabled={processing !== null}
          className={`px-5 py-2.5 rounded-xl font-semibold shadow-lg shadow-dark/20 transition-all
            ${processing !== null ? 'bg-gray-300 text-gray-600 cursor-not-allowed' : 'bg-dark text-white hover:bg-dark-light'}
          `}
        >
          {isCreating ? 'Creating…' : '+ Add Admin'}
        </button>
      </div>

      {/* LIST */}
      <div className="flex flex-col gap-4">
        {admins.map((a) => (
          <div
            key={a.id}
            className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 flex items-center justify-between"
          >
            <div className="flex items-center gap-4">
              <div
                className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl ${
                  a.role === 'superadmin'
                    ? 'bg-purple-100 text-purple-600'
                    : 'bg-dark/5 text-dark'
                }`}
              >
                {a.role === 'superadmin' ? '🔑' : '👔'}
              </div>

              <div>
                <h3 className="font-bold text-text-main">
                  {a.name || 'Unknown Admin'}
                  {a.id === currentUserUid && (
                    <span className="ml-2 text-xs bg-green-100 text-green-600 px-2 py-0.5 rounded-full">
                      You
                    </span>
                  )}
                </h3>

                <div className="flex gap-2 text-sm text-text-sub">
                  <span>{a.email || '—'}</span>
                  <span className="bg-gray-100 px-2 rounded text-xs font-mono uppercase flex items-center">
                    {a.role || 'admin'}
                  </span>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              {/* Only show Delete button if it's NOT the current user */}
              {a.id !== currentUserUid ? (
                <button
                  onClick={() => handleDelete(a.id, a.name)}
                  disabled={isDeletingId(a.id) || processing === 'create'}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors border
                    ${
                      isDeletingId(a.id)
                        ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed'
                        : 'text-red-500 bg-red-50 hover:bg-red-100 border-red-100'
                    }
                  `}
                >
                  {isDeletingId(a.id) ? 'Deleting…' : 'Delete Access'}
                </button>
              ) : (
                <span className="text-xs text-gray-400 italic px-3">Current Session</span>
              )}
            </div>
          </div>
        ))}

        {admins.length === 0 && (
          <div className="text-center py-12 text-text-sub">No admins found.</div>
        )}
      </div>

      {/* MODAL */}
      {showAdd && (
        <AddAdminModal
          onClose={() => (isCreating ? null : setShowAdd(false))}
          onCreate={onCreate}
          isSubmitting={isCreating}
        />
      )}
    </div>
  );
}

function AddAdminModal({ onClose, onCreate, isSubmitting }) {
  const [form, setForm] = useState({ email: '', password: '', name: '' });

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const submit = () => {
    if (isSubmitting) return;
    if (!form.email || !form.password || !form.name) {
      return alert('Name, Email & Password are required.');
    }
    onCreate(form);
  };

  const inputClass =
    'w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-dark/20 bg-gray-50 text-sm mb-3';

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4 z-50">
      <div className="bg-white p-6 rounded-2xl w-full max-w-md shadow-2xl animate-in fade-in zoom-in duration-200">
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-bold text-xl text-text-main">Create New Admin</h3>

          <button
            onClick={onClose}
            disabled={isSubmitting}
            className={`text-gray-400 hover:text-dark ${isSubmitting ? 'opacity-50 cursor-not-allowed' : ''}`}
          >
            ✕
          </button>
        </div>

        <input
          name="name"
          placeholder="Full Name"
          className={inputClass}
          onChange={handleChange}
          value={form.name}
          disabled={isSubmitting}
        />

        <input
          name="email"
          placeholder="Email"
          className={inputClass}
          onChange={handleChange}
          value={form.email}
          disabled={isSubmitting}
        />

        <input
          name="password"
          type="password"
          placeholder="Password"
          className={inputClass}
          onChange={handleChange}
          value={form.password}
          disabled={isSubmitting}
        />

        <div className="flex justify-end gap-3 mt-4 pt-4 border-t border-gray-100">
          <button
            className="px-4 py-2 rounded-xl text-text-sub hover:bg-gray-50 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Cancel
          </button>

          <button
            className="px-4 py-2 rounded-xl bg-dark text-white shadow-lg shadow-dark/20 font-medium hover:bg-dark-light disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={submit}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Creating…' : 'Create Admin'}
          </button>
        </div>
      </div>
    </div>
  );
}
