import React, { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  query,
  where,
  orderBy,
  doc,
  updateDoc,
} from 'firebase/firestore';
import { db, createAgentCallable, deleteUserCallable } from '../firebase';

const ZONES = ['Zone A', 'Zone B', 'Zone C'];
const SHIFT_TYPES = [
  { value: 'weekday', label: 'Weekday (Mon–Thu)' },
  { value: 'weekend', label: 'Weekend (Fri–Sun)' },
];

export default function AgentsPage() {
  const [agents, setAgents] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [editingAgent, setEditingAgent] = useState(null);

  // processing can be: null | "create" | "update:<uid>" | "delete:<uid>"
  const [processing, setProcessing] = useState(null);

  useEffect(() => {
    const q = query(
      collection(db, 'users'),
      where('role', '==', 'agent'),
      orderBy('createdAt', 'desc')
    );
    const unsub = onSnapshot(q, (snap) => {
      setAgents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  const isCreating = processing === 'create';
  const isUpdating = processing?.startsWith('update:');
  const isDeletingId = (id) => processing === `delete:${id}`;

  // CREATE
  const handleCreate = async (payload) => {
    if (isCreating) return;

    setProcessing('create');
    try {
      await createAgentCallable(payload);
      alert('Agent created successfully.');
      setShowAdd(false);
    } catch (e) {
      console.error("createAgent RAW error:", e);
      console.error("code:", e?.code);
      console.error("message:", e?.message);
      console.error("details:", e?.details);

      alert(
        "Failed to create agent:\n" +
          "code: " + (e?.code || "n/a") + "\n" +
          "message: " + (e?.message || "n/a") + "\n" +
          "details: " + JSON.stringify(e?.details || {})
      );
    } finally {
      setProcessing(null);
    }
  };

  // UPDATE
  const handleUpdate = async (updatedData) => {
    if (!editingAgent) return;

    setProcessing(`update:${editingAgent.id}`);
    try {
      await updateDoc(doc(db, 'users', editingAgent.id), updatedData);
      alert('Agent profile updated.');
      setEditingAgent(null);
    } catch (e) {
      console.error(e);
      alert('Update failed: ' + (e.message || 'Unknown error'));
    } finally {
      setProcessing(null);
    }
  };

  // DELETE
  const handleDelete = async (agentId, agentName) => {
    if (
      !window.confirm(
        `⚠️ Delete agent "${agentName || 'Unnamed'}"?\nThis action is permanent.`
      )
    )
      return;

    setProcessing(`delete:${agentId}`);
    try {
      await deleteUserCallable({ targetUid: agentId });
      alert('Agent deleted successfully.');
    } catch (e) {
      console.error(e);
      alert('Delete failed: ' + (e.message || 'Unknown error'));
    } finally {
      setProcessing(null);
    }
  };

  const toggleActive = async (agent) => {
    // optional: also block toggling during delete/update/create
    if (processing) return;

    try {
      await updateDoc(doc(db, 'users', agent.id), { active: !agent.active });
    } catch (e) {
      console.error(e);
      alert('Failed to update status.');
    }
  };

  return (
    <div>
      {/* HEADER */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">
            Agents Management
          </h2>
          <p className="text-text-sub text-sm mt-2">
            Manage your field collection team
          </p>
        </div>

        <button
          onClick={() => setShowAdd(true)}
          disabled={processing !== null}
          className={`px-5 py-2.5 rounded-xl font-semibold shadow-lg transition-all
            ${processing !== null ? 'bg-gray-300 text-gray-600 cursor-not-allowed' : 'bg-dark text-white hover:bg-dark-light'}
          `}
        >
          {isCreating ? 'Creating…' : '+ Add Agent'}
        </button>
      </div>

      {/* LIST */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        {agents.map((a) => (
          <div
            key={a.id}
            className={`bg-white p-5 rounded-2xl shadow-sm border ${
              a.active ? 'border-gray-100' : 'border-red-200 bg-red-50/30'
            }`}
          >
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-4">
                <div
                  className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl ${
                    a.active
                      ? 'bg-blue-50 text-blue-600'
                      : 'bg-gray-200 text-gray-400'
                  }`}
                >
                  {a.active ? '🛡️' : '🚫'}
                </div>

                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-lg">{a.name || 'Unnamed'}</h3>
                    {!a.active && (
                      <span className="text-xs bg-red-100 text-red-600 px-2 py-0.5 rounded font-bold">
                        INACTIVE
                      </span>
                    )}
                  </div>

                  <p className="text-sm text-gray-500">📧 {a.email || '—'}</p>

                  <div className="flex gap-3 text-xs font-mono mt-1 text-gray-400">
                    <span>Agent ID: {a.agentId || '—'}</span>
                    <span>•</span>
                    <span>Zone: {a.zone || 'Unassigned'}</span>
                    <span>Shift: {a.shiftType || '—'}</span>
                  </div>
                </div>
              </div>

              <div className="flex flex-col gap-2">
                <button
                  onClick={() => setEditingAgent(a)}
                  disabled={processing !== null}
                  className={`px-3 py-1.5 text-sm rounded-lg transition-colors
                    ${processing !== null ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'text-blue-600 bg-blue-50 hover:bg-blue-100'}
                  `}
                >
                  Edit
                </button>

                <button
                  onClick={() => toggleActive(a)}
                  disabled={processing !== null}
                  className={`px-3 py-1.5 text-sm rounded-lg transition-colors
                    ${processing !== null ? 'bg-gray-100 text-gray-400 cursor-not-allowed' :
                      a.active
                        ? 'text-orange-600 bg-orange-50 hover:bg-orange-100'
                        : 'text-green-600 bg-green-50 hover:bg-green-100'
                    }`}
                >
                  {a.active ? 'Disable' : 'Enable'}
                </button>
              </div>
            </div>

            <div className="mt-4 pt-4 border-t text-xs text-gray-400 flex justify-between">
              <span>
                Joined:{' '}
                {a.createdAt?.seconds
                  ? new Date(a.createdAt.seconds * 1000).toLocaleDateString(
                      'en-GB'
                    )
                  : 'Unknown'}
              </span>

              <button
                onClick={() => handleDelete(a.id, a.name)}
                disabled={isDeletingId(a.id) || processing?.startsWith('update:') || isCreating}
                className={`hover:underline ${
                  isDeletingId(a.id)
                    ? 'text-gray-400 cursor-not-allowed'
                    : 'text-red-400 hover:text-red-600'
                }`}
              >
                {isDeletingId(a.id) ? 'Deleting…' : 'Delete'}
              </button>
            </div>
          </div>
        ))}
      </div>

      {agents.length === 0 && (
        <div className="text-center py-16 bg-white rounded-2xl border border-dashed text-gray-400">
          No agents found.
        </div>
      )}

      {/* MODALS */}
      {showAdd && (
        <AgentFormModal
          title="Create New Agent"
          onClose={() => (isCreating ? null : setShowAdd(false))}
          onSubmit={handleCreate}
          isCreate
          isSubmitting={isCreating}
        />
      )}

      {editingAgent && (
        <AgentFormModal
          title="Edit Agent Profile"
          initialData={editingAgent}
          onClose={() => (isUpdating ? null : setEditingAgent(null))}
          onSubmit={handleUpdate}
          isCreate={false}
          isSubmitting={processing === `update:${editingAgent.id}`}
        />
      )}
    </div>
  );
}

function AgentFormModal({
  title,
  initialData = {},
  onClose,
  onSubmit,
  isCreate,
  isSubmitting = false,
}) {
  const [form, setForm] = useState({
    name: initialData.name || '',
    email: initialData.email || '',
    password: '',
    phone: initialData.phone || '',
    zone: initialData.zone || '',
    shiftType: initialData.shiftType || '',
  });

  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = () => {
    if (isSubmitting) return;
    if (!form.name) return alert('Name is required');
    if (!form.zone) return alert('Please select a zone.');
    if (!form.shiftType) return alert('Please select shift (weekday/weekend).');
    if (isCreate && (!form.email || !form.password)) {
      return alert('Email & Password required');
    }

    const payload = isCreate
      ? form
      : { name: form.name, phone: form.phone, zone: form.zone, shiftType: form.shiftType };

    onSubmit(payload);
  };

  const inputClass =
    'w-full border border-gray-200 px-4 py-3 rounded-xl bg-gray-50 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20';

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 z-50">
      <div className="bg-white p-6 rounded-2xl w-full max-w-lg shadow-2xl">
        <div className="flex justify-between items-center mb-6">
          <h3 className="font-bold text-xl">{title}</h3>
          <button
            onClick={onClose}
            disabled={isSubmitting}
            className={`text-gray-400 hover:text-black ${
              isSubmitting ? 'cursor-not-allowed opacity-50' : ''
            }`}
          >
            ✕
          </button>
        </div>

        <div className="grid gap-4 mb-6">
          <input
            name="name"
            placeholder="Full Name"
            value={form.name}
            onChange={handleChange}
            className={inputClass}
            disabled={isSubmitting}
          />

          <input
            name="email"
            value={form.email}
            disabled={!isCreate || isSubmitting}
            onChange={handleChange}
            className={`${inputClass} ${
              !isCreate ? 'bg-gray-100 text-gray-500 cursor-not-allowed' : ''
            }`}
            placeholder="Email"
          />

          <input
            name="phone"
            placeholder="Phone"
            value={form.phone}
            onChange={handleChange}
            className={inputClass}
            disabled={isSubmitting}
          />

          {isCreate && (
            <input
              name="password"
              type="password"
              placeholder="Password"
              value={form.password}
              onChange={handleChange}
              className={inputClass}
              disabled={isSubmitting}
            />
          )}

          <div>
            <div className="text-xs font-bold text-gray-400 uppercase mb-1">
              Operational Zone
            </div>
            <select
              name="zone"
              value={form.zone}
              onChange={handleChange}
              className={`${inputClass} appearance-none`}
              disabled={isSubmitting}
            >
              <option value="">Select a zone…</option>
              {ZONES.map((z) => (
                <option key={z} value={z}>
                  {z}
                </option>
              ))}
            </select>
          </div>

          <div>
            <div className="text-xs font-bold text-gray-400 uppercase mb-1">
              Shift Type
            </div>
            <select
              name="shiftType"
              value={form.shiftType}
              onChange={handleChange}
              className={`${inputClass} appearance-none`}
              disabled={isSubmitting}
            >
              <option value="">Select shift…</option>
              {SHIFT_TYPES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
          <button
            onClick={onClose}
            disabled={isSubmitting}
            className="px-5 py-2.5 rounded-xl text-gray-500 hover:bg-gray-50 font-medium disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="px-5 py-2.5 rounded-xl bg-dark text-white font-medium hover:bg-dark-light shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? (isCreate ? 'Creating…' : 'Saving…') : isCreate ? 'Create Agent' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}
