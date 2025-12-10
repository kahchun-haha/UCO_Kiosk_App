import { collection, onSnapshot } from 'firebase/firestore';
import { useEffect, useState } from 'react';
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

  // Function to determine if kiosk is online (e.g., updated in last 15 mins)
  const isKioskOnline = (lastUpdated) => {
    if (!lastUpdated) return false;
    const now = new Date();
    const lastUpdateDate = new Date(lastUpdated.seconds * 1000);
    const diffInMinutes = (now - lastUpdateDate) / 1000 / 60;
    return diffInMinutes < 15; // Considered online if updated within 15 mins
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
          const statusClass = getStatusColor(fill);
          const isOnline = isKioskOnline(k.lastUpdated || k.lastCollected); // Check online status
          
          // Display Name Logic: Location -> Kiosk Name -> "Unknown Location"
          const displayName = k.location || k.name || 'Unknown Location';

          return (
            <div key={k.id} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex flex-col justify-between h-full relative overflow-hidden">
              
              {/* Online/Offline Indicator Strip */}
              <div className={`absolute top-0 left-0 w-1 h-full ${isOnline ? 'bg-green-500' : 'bg-gray-300'}`}></div>

              <div className="flex justify-between items-start mb-4 pl-2">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-lg text-text-main">{displayName}</h3>
                    {/* Online/Offline Dot */}
                    <span className={`w-2.5 h-2.5 rounded-full ${isOnline ? 'bg-green-500 animate-pulse' : 'bg-gray-400'}`} title={isOnline ? "Online" : "Offline"}></span>
                  </div>
                  {/* Full ID Display */}
                  <p className="text-xs text-text-sub font-mono mt-1 select-all" title={k.id}>ID: {k.id}</p>
                </div>
                <div className={`px-3 py-1 rounded-full text-sm font-bold border ${statusClass}`}>
                  {fill}% Full
                </div>
              </div>

              {/* Visual Fill Bar */}
              <div className="w-full bg-gray-100 h-3 rounded-full overflow-hidden mb-6 mx-2" style={{width: 'calc(100% - 16px)'}}>
                <div 
                  className={`h-full transition-all duration-500 ${fill > 80 ? 'bg-red-500' : fill > 50 ? 'bg-orange-500' : 'bg-primary'}`} 
                  style={{ width: `${fill}%` }}
                ></div>
              </div>

              <div className="mt-auto space-y-2 border-t border-gray-100 pt-4 pl-2">
                <div className="flex justify-between text-sm">
                  <span className="text-text-sub">Last Updated:</span>
                  <span className="font-medium text-text-main">
                    {/* Prefer lastUpdated timestamp, fallback to lastCollected */}
                    {(k.lastUpdated || k.lastCollected) ? new Date((k.lastUpdated || k.lastCollected).seconds * 1000).toLocaleString('en-GB') : 'Never'}
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