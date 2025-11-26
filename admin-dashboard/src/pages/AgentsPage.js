import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, where, orderBy, doc, updateDoc } from 'firebase/firestore';
import { db, createAgentCallable, deleteUserCallable } from '../firebase';

export default function AgentsPage() {
  const [agents, setAgents] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [editingAgent, setEditingAgent] = useState(null); // Stores the agent being edited
  const [processing, setProcessing] = useState(null); // Track which ID is loading

  // Listen to real-time updates for Agents only
  useEffect(() => {
    const q = query(
      collection(db, 'users'), 
      where('role', '==', 'agent'), 
      orderBy('createdAt', 'desc')
    );
    const unsub = onSnapshot(q, (snap) => {
      setAgents(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  // 1. CREATE NEW AGENT
  const handleCreate = async (payload) => {
    try {
      await createAgentCallable(payload);
      alert('Agent created successfully.');
      setShowAdd(false);
    } catch (e) {
      console.error(e);
      alert('Failed to create agent: ' + e.message);
    }
  };

  // 2. UPDATE EXISTING AGENT (Fixing the "Useless" Edit)
  const handleUpdate = async (updatedData) => {
    if (!editingAgent) return;
    
    setProcessing(editingAgent.id);
    try {
      // We use direct Firestore update because you are an Admin (allowed by Rules)
      await updateDoc(doc(db, 'users', editingAgent.id), updatedData);
      alert('Agent profile updated.');
      setEditingAgent(null); // Close modal
    } catch (e) {
      console.error(e);
      alert('Update failed: ' + e.message);
    } finally {
      setProcessing(null);
    }
  };

  // 3. DELETE AGENT
  const handleDelete = async (agentId, agentName) => {
    if(!window.confirm(`⚠️ DANGER: Are you sure you want to delete "${agentName}"?\n\nThis will permanently remove their login access and data.`)) return;

    setProcessing(agentId);
    try {
      await deleteUserCallable({ targetUid: agentId });
      alert('Agent deleted successfully.');
    } catch (e) {
      console.error(e);
      alert('Delete failed: ' + e.message);
    } finally {
      setProcessing(null);
    }
  };

  // 4. TOGGLE STATUS (Active/Inactive)
  const toggleActive = async (agent) => {
    try {
      await updateDoc(doc(db, 'users', agent.id), { active: !agent.active });
    } catch (e) {
      alert('Failed to update status.');
    }
  };

  return (
    <div>
      {/* HEADER */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-text-main">Agents Management</h2>
          <p className="text-text-sub text-sm">Manage your field collection team</p>
        </div>
        <button 
          onClick={() => setShowAdd(true)} 
          className="bg-dark text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-dark-light shadow-lg shadow-dark/20 transition-all flex items-center gap-2"
        >
          <span>+</span> Add Agent
        </button>
      </div>

      {/* AGENT LIST CARDS */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        {agents.map(a => (
          <div key={a.id} className={`bg-white p-5 rounded-2xl shadow-sm border transition-all ${a.active ? 'border-gray-100' : 'border-red-100 bg-red-50/30'}`}>
            <div className="flex justify-between items-start">
              
              {/* Agent Info */}
              <div className="flex items-center gap-4">
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl ${a.active ? 'bg-blue-50 text-blue-600' : 'bg-gray-200 text-gray-400'}`}>
                  {a.active ? '🛡️' : '🚫'}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-text-main text-lg">{a.name || 'Unnamed Agent'}</h3>
                    {!a.active && <span className="text-xs bg-red-100 text-red-600 px-2 py-0.5 rounded font-bold">INACTIVE</span>}
                  </div>
                  <div className="text-sm text-text-sub space-y-0.5">
                    <p>📧 {a.email}</p>
                    <div className="flex gap-3 text-xs font-mono mt-1 text-gray-400">
                      <span>ID: {a.staffId || 'N/A'}</span>
                      <span>•</span>
                      <span>Region: {a.region || 'Unassigned'}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Actions Toolbar */}
              <div className="flex flex-col gap-2">
                <button 
                  onClick={() => setEditingAgent(a)}
                  className="px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors"
                >
                  Edit
                </button>
                <button 
                  onClick={() => toggleActive(a)}
                  className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${a.active ? 'text-orange-600 bg-orange-50 hover:bg-orange-100' : 'text-green-600 bg-green-50 hover:bg-green-100'}`}
                >
                  {a.active ? 'Disable' : 'Enable'}
                </button>
              </div>
            </div>

            {/* Footer / Stats */}
            <div className="mt-4 pt-4 border-t border-gray-100 flex justify-between items-center">
              <div className="text-xs text-gray-400">
                Joined: {a.createdAt ? new Date(a.createdAt.seconds * 1000).toLocaleDateString('en-GB') : 'Unknown'}
              </div>
              <button 
                onClick={() => handleDelete(a.id, a.name)}
                disabled={processing === a.id}
                className="text-xs text-red-400 hover:text-red-600 hover:underline px-2"
              >
                {processing === a.id ? 'Deleting...' : 'Delete Account'}
              </button>
            </div>
          </div>
        ))}
      </div>
      
      {agents.length === 0 && (
        <div className="text-center py-16 bg-white rounded-2xl border border-dashed border-gray-200 text-text-sub">
          No agents found. Add one to get started.
        </div>
      )}

      {/* MODALS */}
      {showAdd && <AgentFormModal title="Create New Agent" onClose={() => setShowAdd(false)} onSubmit={handleCreate} isCreate={true} />}
      
      {editingAgent && (
        <AgentFormModal 
          title="Edit Agent Profile" 
          initialData={editingAgent} 
          onClose={() => setEditingAgent(null)} 
          onSubmit={handleUpdate}
          isCreate={false}
        />
      )}
    </div>
  );
}

// --- REUSABLE FORM MODAL (Used for both Create and Edit) ---
function AgentFormModal({ title, initialData = {}, onClose, onSubmit, isCreate }) {
  // If editing, prepopulate. If creating, empty.
  const [form, setForm] = useState({
    name: initialData.name || '',
    email: initialData.email || '',
    password: '', // Password only for creation
    phone: initialData.phone || '',
    staffId: initialData.staffId || '',
    region: initialData.region || ''
  });

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = () => {
    if (isCreate && (!form.email || !form.password)) return alert('Email & Password required.');
    if (!form.name) return alert('Name is required.');
    
    // If editing, we don't send email/password to the update function unless you implemented that logic
    // For this simple version, we only update profile fields
    const payload = isCreate ? form : {
      name: form.name,
      phone: form.phone,
      staffId: form.staffId,
      region: form.region
    };
    
    onSubmit(payload);
  };

  const inputClass = "w-full border border-gray-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 bg-gray-50 text-sm";

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4 z-50">
      <div className="bg-white p-6 rounded-2xl w-full max-w-lg shadow-2xl animate-in fade-in zoom-in duration-200">
        <div className="flex justify-between items-center mb-6">
          <h3 className="font-bold text-xl text-text-main">{title}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-dark text-xl">✕</button>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div className="col-span-2">
            <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Full Name</label>
            <input name="name" value={form.name} onChange={handleChange} className={inputClass} />
          </div>

          {/* Email is read-only during Edit to prevent auth issues */}
          <div className="col-span-2 md:col-span-1">
            <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Email</label>
            <input 
              name="email" 
              value={form.email} 
              onChange={handleChange} 
              className={`${inputClass} ${!isCreate ? 'bg-gray-100 text-gray-500 cursor-not-allowed' : ''}`}
              disabled={!isCreate} 
            />
          </div>

          <div className="col-span-2 md:col-span-1">
            <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Phone</label>
            <input name="phone" value={form.phone} onChange={handleChange} className={inputClass} />
          </div>

          {isCreate && (
            <div className="col-span-2">
              <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Password</label>
              <input name="password" type="password" value={form.password} onChange={handleChange} className={inputClass} />
            </div>
          )}

          <div className="col-span-2 md:col-span-1">
            <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Staff ID</label>
            <input name="staffId" value={form.staffId} onChange={handleChange} className={inputClass} />
          </div>

          <div className="col-span-2 md:col-span-1">
            <label className="block text-xs font-bold text-gray-400 uppercase mb-1">Region / Area</label>
            <input name="region" value={form.region} onChange={handleChange} className={inputClass} />
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
          <button className="px-5 py-2.5 rounded-xl text-text-sub hover:bg-gray-50 font-medium transition-colors" onClick={onClose}>Cancel</button>
          <button className="px-5 py-2.5 rounded-xl bg-dark text-white font-medium hover:bg-dark-light shadow-lg shadow-dark/20 transition-all" onClick={handleSubmit}>
            {isCreate ? 'Create Agent' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}