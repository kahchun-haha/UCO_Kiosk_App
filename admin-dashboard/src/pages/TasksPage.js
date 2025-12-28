// src/pages/TasksPage.js
import React, { useEffect, useMemo, useState } from 'react';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  where,
  updateDoc,
  doc,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';
import { reassignPendingTasksByShiftManualCallable } from "../firebase";

const runShiftReassignNow = async () => {
  try {
    const res = await reassignPendingTasksByShiftManualCallable();
    console.log("Manual shift reassign result:", res.data);
    alert(
      `Done ✅\nShiftType=${res.data.targetShiftType}\nReassigned=${res.data.reassigned}`
    );
  } catch (e) {
    console.error(e);
    alert("Failed: " + (e.message || "Unknown error"));
  }
};


export default function TasksPage() {
  const [tasks, setTasks] = useState([]);
  const [agents, setAgents] = useState([]);
  const [filter, setFilter] = useState('active'); // 'active' | 'pending' | 'in_progress' | 'completed' | 'all'
  const [assigningTask, setAssigningTask] = useState(null);
  const [processingId, setProcessingId] = useState(null);

  // --- Load tasks (live) ---
  useEffect(() => {
    const q = query(collection(db, 'collectionTasks'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setTasks(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  // --- Load agents for assignment dropdown (ACTIVE ONLY) ✅ + fallback ✅ ---
  useEffect(() => {
    const qActive = query(
      collection(db, 'users'),
      where('role', '==', 'agent'),
      where('active', '==', true),
      orderBy('createdAt', 'desc')
    );

    const qFallback = query(
      collection(db, 'users'),
      where('role', '==', 'agent'),
      orderBy('createdAt', 'desc')
    );

    let fallbackUnsub = null;

    const unsub = onSnapshot(
      qActive,
      (snap) => {
        setAgents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
      },
      (err) => {
        console.error('Agents query (active-only) failed:', err);

        // attach fallback listener only once
        if (!fallbackUnsub) {
          fallbackUnsub = onSnapshot(qFallback, (snap) => {
            setAgents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
          });
        }
      }
    );

    return () => {
      unsub();
      if (fallbackUnsub) fallbackUnsub();
    };
  }, []);

  // --- Filtering + some quick counts ---
  const { filteredTasks, stats } = useMemo(() => {
    const stats = {
      total: tasks.length,
      pending: tasks.filter((t) => t.status === 'pending').length,
      inProgress: tasks.filter((t) => t.status === 'in_progress').length,
      completed: tasks.filter((t) => t.status === 'completed').length,
    };

    let list = [...tasks];
    if (filter === 'active') {
      list = list.filter((t) => t.status === 'pending' || t.status === 'in_progress');
    } else if (filter === 'pending') {
      list = list.filter((t) => t.status === 'pending');
    } else if (filter === 'in_progress') {
      list = list.filter((t) => t.status === 'in_progress');
    } else if (filter === 'completed') {
      list = list.filter((t) => t.status === 'completed');
    } // 'all' => no filter

    return { filteredTasks: list, stats };
  }, [tasks, filter]);

  // --- Helpers ---
  const statusDisplay = (status) => {
    switch (status) {
      case 'pending':
        return { label: 'Pending', className: 'bg-yellow-100 text-yellow-700' };
      case 'in_progress':
        return { label: 'In Progress', className: 'bg-blue-100 text-blue-700' };
      case 'completed':
        return { label: 'Completed', className: 'bg-green-100 text-green-700' };
      case 'delayed':
        return { label: 'Delayed', className: 'bg-red-100 text-red-700' };
      default:
        return { label: status || 'Unknown', className: 'bg-gray-100 text-gray-600' };
    }
  };

  const formatDateTime = (ts) => {
    if (!ts) return '—';
    try {
      if (ts.toDate) return ts.toDate().toLocaleString('en-GB');
      if (ts.seconds) return new Date(ts.seconds * 1000).toLocaleString('en-GB');
      return '—';
    } catch {
      return '—';
    }
  };

  // --- Admin actions ---
  const handleForceComplete = async (task) => {
    if (!window.confirm('Force mark this task as completed?')) return;
    setProcessingId(task.id);
    try {
      await updateDoc(doc(db, 'collectionTasks', task.id), {
        status: 'completed',
        completedAt: serverTimestamp(),
      });
    } catch (e) {
      console.error(e);
      alert('Failed to update task.');
    } finally {
      setProcessingId(null);
    }
  };

  const handleOpenAssignModal = (task) => {
    setAssigningTask(task);
  };

  const handleViewProof = (task) => {
    if (!task.proofPhotoUrl) return;
    window.open(task.proofPhotoUrl, '_blank', 'noopener,noreferrer');
  };

  return (
    <div>
      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">Collection Tasks</h2>
          <p className="text-text-sub text-sm mt-1">Monitor kiosk pick-ups and manage assignments.</p>
        </div>
        <button
  onClick={runShiftReassignNow}
  className="px-4 py-2 rounded-xl bg-dark text-white text-sm font-semibold"
>
  Run Shift Reassign (Manual)
</button>

        {/* STATUS SUMMARY */}
        <div className="flex flex-wrap gap-2 text-xs md:text-sm">
          <SummaryPill label="Total" value={stats.total} />
          <SummaryPill label="Pending" value={stats.pending} color="bg-yellow-50 text-yellow-700" />
          <SummaryPill label="In Progress" value={stats.inProgress} color="bg-blue-50 text-blue-700" />
          <SummaryPill label="Completed" value={stats.completed} color="bg-green-50 text-green-700" />
        </div>
      </div>

      {/* FILTER BAR */}
      <div className="flex flex-wrap gap-2 mb-5 text-sm">
        <FilterChip label="Active" value="active" current={filter} onChange={setFilter} />
        <FilterChip label="Pending" value="pending" current={filter} onChange={setFilter} />
        <FilterChip label="In Progress" value="in_progress" current={filter} onChange={setFilter} />
        <FilterChip label="Completed" value="completed" current={filter} onChange={setFilter} />
        <FilterChip label="All" value="all" current={filter} onChange={setFilter} />
      </div>

      {/* TASK CARDS */}
      <div className="flex flex-col gap-4">
        {filteredTasks.map((t) => {
          const statusInfo = statusDisplay(t.status);
          const isCompleted = t.status === 'completed';
          const hasProof = !!t.proofPhotoUrl;

          return (
            <div
              key={t.id}
              className={`bg-white p-5 rounded-2xl border shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-4 transition-all ${
                isCompleted ? 'border-gray-100 hover:border-gray-200' : 'border-gray-100 hover:border-primary/30'
              }`}
            >
              {/* LEFT */}
              <div className="flex items-start gap-4 flex-1">
                <div className={`p-3 rounded-xl text-2xl ${isCompleted ? 'bg-green-50 text-green-600' : 'bg-orange-50 text-orange-500'}`}>
                  {isCompleted ? '✅' : '🚛'}
                </div>

                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className={`font-bold text-lg ${isCompleted ? 'text-gray-600' : 'text-text-main'}`}>
                      {t.kioskName || t.kioskId || 'Unknown kiosk'}
                    </h3>

                    <span className={`text-[11px] px-2 py-0.5 rounded-full font-semibold ${statusInfo.className}`}>
                      {statusInfo.label.toUpperCase()}
                    </span>

                    {typeof t.fillLevelAtCreation === 'number' && (
                      <span className="text-[11px] px-2 py-0.5 rounded-full bg-primary/5 text-primary font-semibold">
                        {t.fillLevelAtCreation}% full when created
                      </span>
                    )}

                    {t.zone && (
                      <span className="text-[11px] px-2 py-0.5 rounded-full bg-gray-50 text-gray-600 font-semibold">
                        {t.zone}
                      </span>
                    )}
                  </div>

                  <p className="text-xs text-text-sub font-mono">
                    Task ID: <span className="break-all">{t.id}</span>
                  </p>

                  <div className="flex flex-wrap gap-x-6 gap-y-1 text-xs text-text-sub mt-2">
                    <span><span className="font-semibold">Created:</span> {formatDateTime(t.createdAt)}</span>
                    {t.assignedAt && <span><span className="font-semibold">Assigned:</span> {formatDateTime(t.assignedAt)}</span>}
                    {t.completedAt && <span><span className="font-semibold">Completed:</span> {formatDateTime(t.completedAt)}</span>}
                  </div>

                  <div className="mt-2 text-xs text-text-sub flex flex-wrap gap-4">
                    <span>
                      <span className="font-semibold text-text-main">Agent: </span>
                      {t.agentName ? `${t.agentName} ${t.agentId ? `( ${t.agentId} )` : ''}` : t.agentId ? t.agentId : 'Unassigned'}
                    </span>
                    {t.completionNotes && (
                      <span className="truncate max-w-xs">
                        <span className="font-semibold text-text-main">Notes: </span>
                        {t.completionNotes}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* RIGHT */}
              <div className="flex flex-col items-stretch gap-2 md:w-56">
                {hasProof && (
                  <button
                    onClick={() => handleViewProof(t)}
                    className="px-4 py-2 text-xs font-medium rounded-xl border border-gray-200 text-text-main bg-gray-50 hover:bg-gray-100 transition-colors flex items-center justify-center gap-2"
                  >
                    <span>🖼️</span>
                    <span>View proof photo</span>
                  </button>
                )}

                {(t.status === 'pending' || t.status === 'in_progress') ? (
                  <button
                    onClick={() => handleOpenAssignModal(t)}
                    className="px-4 py-2 text-xs md:text-sm font-semibold rounded-xl bg-dark text-white hover:bg-dark-light shadow-md shadow-dark/20 transition-all flex items-center justify-center gap-2"
                  >
                    <span>👤</span>
                    <span>{t.agentId ? 'Reassign Agent' : 'Assign Agent'}</span>
                  </button>
                ) : null}

                {!isCompleted && (
                  <button
                    onClick={() => handleForceComplete(t)}
                    disabled={processingId === t.id}
                    className="px-4 py-2 text-xs md:text-sm font-medium rounded-xl border border-gray-200 text-red-500 hover:bg-red-50 disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
                  >
                    {processingId === t.id ? 'Updating…' : 'Force mark completed'}
                  </button>
                )}
              </div>
            </div>
          );
        })}

        {filteredTasks.length === 0 && (
          <div className="text-center py-16 bg-white rounded-2xl border border-dashed border-gray-200 text-text-sub">
            No tasks found for this filter.
          </div>
        )}
      </div>

      {/* ASSIGN MODAL */}
      {assigningTask && (
        <AssignAgentModal
          task={assigningTask}
          agents={agents}
          onClose={() => setAssigningTask(null)}
        />
      )}
    </div>
  );
}

/* ---------------- Helpers ---------------- */

function SummaryPill({ label, value, color = 'bg-gray-50 text-text-sub' }) {
  return (
    <div className="px-3 py-2 rounded-xl border border-gray-100 text-xs md:text-sm flex items-center gap-2 bg-white shadow-sm">
      <span
        className={`w-2 h-2 rounded-full ${
          color.includes('green') ? 'bg-green-500'
          : color.includes('yellow') ? 'bg-yellow-400'
          : color.includes('blue') ? 'bg-blue-500'
          : 'bg-gray-300'
        }`}
      />
      <span className="text-text-sub">{label}</span>
      <span className="font-semibold text-text-main">{value}</span>
    </div>
  );
}

function FilterChip({ label, value, current, onChange }) {
  const isActive = current === value;
  return (
    <button
      onClick={() => onChange(value)}
      className={`px-3 py-1.5 rounded-full border text-xs md:text-sm font-medium transition-colors ${
        isActive
          ? 'bg-dark text-white border-dark shadow-md shadow-dark/20'
          : 'bg-white text-text-sub border-gray-200 hover:bg-gray-50'
      }`}
    >
      {label}
    </button>
  );
}

/* ---------------- Assign Modal ---------------- */

function AssignAgentModal({ task, agents, onClose }) {
  const [selectedUid, setSelectedUid] = useState('');
  const [saving, setSaving] = useState(false);

  const filteredAgents = agents.filter(
    (a) => a.active === true && a.zone === task.zone
  );

  // ✅ keep selection valid (active + same zone). No eslint-disable needed.
  useEffect(() => {
    const stillValid =
      task.agentUid &&
      agents.some(
        (a) =>
          a.active === true &&
          a.zone === task.zone &&
          a.id === task.agentUid
      );

    setSelectedUid(stillValid ? task.agentUid : '');
  }, [task.agentUid, task.zone, agents]);

  const handleSave = async () => {
    if (!task.zone) {
      alert('This task has no zone. Please set kiosk/task zone first.');
      return;
    }
    if (!selectedUid) {
      alert('Please select an agent.');
      return;
    }

    const agent = filteredAgents.find((a) => a.id === selectedUid);
    if (!agent) {
      alert('Agent not found (inactive or zone mismatch).');
      return;
    }

    setSaving(true);
    try {
      await updateDoc(doc(db, 'collectionTasks', task.id), {
        agentUid: agent.id,
        agentId: agent.agentId || null,
        agentName: agent.name || agent.email || '',
        assignedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        status: 'pending',
      });
      onClose();
    } catch (e) {
      console.error(e);
      alert('Failed to assign agent.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-dark/40 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl p-6">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-bold text-text-main">Assign Agent</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-dark text-xl">✕</button>
        </div>

        <p className="text-sm text-text-sub mb-2">
          Kiosk: <span className="font-semibold text-text-main">{task.kioskName || task.kioskId}</span>
        </p>
        <p className="text-sm text-text-sub mb-4">
          Zone: <span className="font-semibold text-text-main">{task.zone || '—'}</span>
        </p>

        <label className="block text-xs font-bold text-gray-400 uppercase mb-2">
          Select Agent (Active + same zone)
        </label>

        <select
          value={selectedUid}
          onChange={(e) => setSelectedUid(e.target.value)}
          className="w-full border border-gray-200 rounded-xl px-4 py-3 bg-gray-50 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
          disabled={!task.zone}
        >
          <option value="">-- Choose an agent --</option>
          {filteredAgents.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name || a.email} {a.agentId ? `( ${a.agentId} )` : ''} • {a.zone}
            </option>
          ))}
        </select>

        {(!task.zone || filteredAgents.length === 0) && (
          <p className="mt-2 text-xs text-red-500">
            {!task.zone
              ? 'This task has no zone. Set kiosk/task zone first.'
              : `No active agents found for ${task.zone}. Enable or create one in Agents page.`}
          </p>
        )}

        <div className="flex justify-end gap-3 mt-6">
          <button className="px-4 py-2 rounded-xl text-sm text-text-sub hover:bg-gray-50" onClick={onClose}>
            Cancel
          </button>
          <button
            disabled={saving || !task.zone || filteredAgents.length === 0}
            onClick={handleSave}
            className="px-5 py-2 rounded-xl bg-dark text-white text-sm font-medium hover:bg-dark-light shadow-lg shadow-dark/20 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {saving ? 'Saving…' : task.agentId ? 'Update Assignment' : 'Assign Agent'}
          </button>
        </div>
      </div>
    </div>
  );
}
