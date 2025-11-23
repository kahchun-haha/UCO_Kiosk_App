import React, { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';

export default function KiosksPage() {
  const [kiosks, setKiosks] = useState([]);
  
  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'kiosks'), (snap) => {
      setKiosks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  const getStatusColor = (fill) => {
    if (fill >= 80) return 'bg-red-100 text-red-600 border-red-200'; // Critical
    if (fill >= 50) return 'bg-orange-100 text-orange-600 border-orange-200'; // Warning
    return 'bg-green-100 text-green-600 border-green-200'; // Good
  };

  return (
    <div>
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-text-main">Kiosk Status</h2>
        <p className="text-text-sub text-sm">Live monitoring of oil levels</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {kiosks.map(k => {
          const fill = k.fillLevel || 0;
          const statusClass = getStatusColor(fill);
          
          return (
            <div key={k.id} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex flex-col justify-between h-full">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="font-bold text-lg text-text-main">{k.location || 'Unknown Location'}</h3>
                  <p className="text-xs text-text-sub font-mono mt-1">ID: {k.id.slice(0,8)}...</p>
                </div>
                <div className={`px-3 py-1 rounded-full text-sm font-bold border ${statusClass}`}>
                  {fill}% Full
                </div>
              </div>

              {/* Visual Fill Bar */}
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden mb-6">
                <div 
                  className={`h-full transition-all duration-500 ${fill > 80 ? 'bg-red-500' : fill > 50 ? 'bg-orange-500' : 'bg-primary'}`} 
                  style={{ width: `${fill}%` }}
                ></div>
              </div>

              <div className="mt-auto space-y-2 border-t border-gray-100 pt-4">
                <div className="flex justify-between text-sm">
                  <span className="text-text-sub">Last Collected:</span>
                  <span className="font-medium text-text-main">
                    {k.lastCollected ? new Date(k.lastCollected.seconds*1000).toLocaleDateString() : 'Never'}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-sub">Agent:</span>
                  <span className="font-medium text-text-main">{k.assignedAgent || 'Unassigned'}</span>
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