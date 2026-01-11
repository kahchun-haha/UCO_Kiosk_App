import { collection, onSnapshot, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { db } from '../firebase';

export default function KiosksPage() {
  const [kiosks, setKiosks] = useState([]);
  const [savingId, setSavingId] = useState(null);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'kiosks'), (snap) => {
      setKiosks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  // Fill badge color
  const getFillClass = (fill) => {
    if (fill >= 80) return 'bg-red-100 text-red-600 border-red-200';
    if (fill >= 50) return 'bg-orange-100 text-orange-600 border-orange-200';
    return 'bg-green-100 text-green-600 border-green-200';
  };

  // Status badge color
  const getStatusClass = (status) => {
    const s = (status || 'online').toLowerCase();
    if (s === 'maintenance') return 'bg-gray-100 text-gray-700 border-gray-200';
    if (s === 'offline') return 'bg-slate-100 text-slate-600 border-slate-200';
    return 'bg-emerald-100 text-emerald-700 border-emerald-200'; // online
  };

  const getIndicatorStripClass = (status) => {
  const s = (status || 'online').toLowerCase();
  if (s === 'online') return 'bg-green-500';
  if (s === 'maintenance') return 'bg-orange-500';
  return 'bg-gray-300'; // offline
  };

  const getIndicatorDotClass = (status) => {
    const s = (status || 'online').toLowerCase();
    if (s === 'online') return 'bg-green-500 animate-pulse';
    if (s === 'maintenance') return 'bg-orange-500';
    return 'bg-gray-400'; // offline
  };

  const fmtTs = (ts) => {
    if (!ts?.seconds) return 'Never';
    return new Date(ts.seconds * 1000).toLocaleString('en-GB');
  };

  // ✅ Admin control: set status
  const setKioskStatus = async (kioskId, newStatus) => {
    try {
      setSavingId(kioskId);

      let patch = {
        status: newStatus,
        maintenanceUpdatedAt: serverTimestamp(),
      };

      if (newStatus === 'maintenance') {
        const reason = window.prompt('Maintenance reason (optional):', '');
        patch.maintenanceReason = reason ? reason.trim() : '';
      } else {
        // clear reason when not maintenance
        patch.maintenanceReason = '';
      }

      await updateDoc(doc(db, 'kiosks', kioskId), patch);
    } catch (e) {
      console.error(e);
      alert('Failed to update kiosk status. Check Firestore rules.');
    } finally {
      setSavingId(null);
    }
  };

  return (
    <div>
      <div className="mb-6">
        <h2 className="text-3xl font-bold text-text-main mb-1">Kiosk Status</h2>
        <p className="text-text-sub text-sm mt-2">Live monitoring of oil levels</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {kiosks.map(k => {
          const fill = k.fillLevel || 0;
          const fillClass = getFillClass(fill);

          // ✅ use Firestore status field (no more 15-min rule)
          const status = (k.status || 'online').toLowerCase();
          const statusClass = getStatusClass(status);

          const displayName = k.location || k.name || 'Unknown Location';

          // ✅ fix agent display:
          // priority: lastCollectedByAgentId -> assignedAgentId -> assignedAgentUid -> '-'
          const agentDisplay =
            k.lastCollectedByAgentId ||
            k.assignedAgentId ||
            k.assignedAgentUid ||
            '-';

          return (
            <div
              key={k.id}
              className="bg-white p-6 pl-7 rounded-2xl shadow-sm border border-gray-100 flex flex-col justify-between h-full relative overflow-hidden"
            >
              <div className={`absolute top-0 left-0 w-1 h-full ${getIndicatorStripClass(status)}`} />
              <div className="flex justify-between items-start mb-4">
                <div>
                  <div className="flex items-center gap-2">
                  <h3 className="font-bold text-lg text-text-main">{displayName}</h3>
                  <span
                    className={`w-2.5 h-2.5 rounded-full ${getIndicatorDotClass(status)}`}
                    title={status === 'online' ? 'Online' : status === 'maintenance' ? 'Maintenance' : 'Offline'}
                  />
                </div>
                  <p className="text-xs text-text-sub font-mono mt-1 select-all" title={k.id}>
                    ID: {k.id}
                  </p>

                  {/* ✅ Status badge */}
                  <div className="mt-2 flex gap-2 items-center">
                    <span className={`px-3 py-1 rounded-full text-xs font-bold border ${statusClass}`}>
                      {status.toUpperCase()}
                    </span>

                    {/* show maintenance reason if any */}
                    {status === 'maintenance' && k.maintenanceReason ? (
                      <span className="text-xs text-text-sub italic" title={k.maintenanceReason}>
                        {k.maintenanceReason}
                      </span>
                    ) : null}
                  </div>
                </div>

                {/* Fill badge */}
                <div className={`px-3 py-1 rounded-full text-sm font-bold border ${fillClass}`}>
                  {fill}% Full
                </div>
              </div>

              {/* Visual Fill Bar */}
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden mb-6">
                <div
                  className={`${fill > 80 ? 'bg-red-500' : fill > 50 ? 'bg-orange-500' : 'bg-primary'} h-full transition-all duration-500`}
                  style={{ width: `${fill}%` }}
                />
              </div>

              <div className="mt-auto space-y-2 border-t border-gray-100 pt-4">
                {/* ✅ change to Last Collected (not lastUpdated) */}
                <div className="flex justify-between text-sm">
                  <span className="text-text-sub">Last Collected:</span>
                  <span className="font-medium text-text-main">
                    {fmtTs(k.lastCollected)}
                  </span>
                </div>

                <div className="flex justify-between text-sm">
                  <span className="text-text-sub">Last Agent:</span>
                  <span className="font-medium text-text-main">{agentDisplay}</span>
                </div>

                {/* ✅ Admin status control */}
                <div className="pt-3 flex gap-2">
                  <button
                    disabled={savingId === k.id}
                    onClick={() => setKioskStatus(k.id, 'online')}
                    className="flex-1 text-sm px-3 py-2 rounded-xl border border-gray-200 hover:bg-gray-50"
                  >
                    {savingId === k.id ? 'Saving…' : 'Set Online'}
                  </button>
                  <button
                    disabled={savingId === k.id}
                    onClick={() => setKioskStatus(k.id, 'maintenance')}
                    className="flex-1 text-sm px-3 py-2 rounded-xl border border-gray-200 hover:bg-gray-50"
                  >
                    Maintenance
                  </button>
                  <button
                    disabled={savingId === k.id}
                    onClick={() => setKioskStatus(k.id, 'offline')}
                    className="flex-1 text-sm px-3 py-2 rounded-xl border border-gray-200 hover:bg-gray-50"
                  >
                    Offline
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {kiosks.length === 0 && (
          <div className="col-span-full text-center py-12 text-text-sub">
            No kiosks configured.
          </div>
        )}
      </div>
    </div>
  );
}
