import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy, where } from 'firebase/firestore';
import { db } from '../firebase';

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  // NEW: State for sorting
  const [sortConfig, setSortConfig] = useState({ key: 'joined', direction: 'desc' });

  useEffect(() => {
    const q = query(
      collection(db, 'users'),
      where('role', '==', 'user'),
      orderBy('createdAt', 'desc')
    );
    
    const unsub = onSnapshot(q, (snap) => {
      const userList = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(userList);
    });
    
    return () => unsub();
  }, []);

  // --- SORTING LOGIC ---
  const handleSort = (key) => {
    let direction = 'desc';
    if (sortConfig.key === key && sortConfig.direction === 'desc') {
      direction = 'asc';
    }
    setSortConfig({ key, direction });
  };

  const sortedUsers = [...users].sort((a, b) => {
    // Helper to get values safely
    const getVal = (user, key) => {
      if (key === 'deposits') return user.depositCount || 0;
      if (key === 'volume') return user.totalRecycled || 0;
      if (key === 'joined') return user.createdAt?.seconds || 0;
      return 0;
    };

    const valA = getVal(a, sortConfig.key);
    const valB = getVal(b, sortConfig.key);

    if (valA < valB) return sortConfig.direction === 'asc' ? -1 : 1;
    if (valA > valB) return sortConfig.direction === 'asc' ? 1 : -1;
    return 0;
  });

  // Helper for sort indicator icons
  const SortIcon = ({ column }) => {
    if (sortConfig.key !== column) return <span className="text-gray-300 ml-1">↕</span>;
    return <span className="text-primary ml-1">{sortConfig.direction === 'asc' ? '↑' : '↓'}</span>;
  };

  return (
    <div>
      {/* HEADER */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-text-main">Registered Users</h2>
          <p className="text-text-sub text-sm">View details of all app users</p>
        </div>
        
        <div className="flex gap-4 items-center">
          <div className="bg-white px-4 py-2 rounded-xl border border-gray-100 text-sm font-medium text-text-main shadow-sm">
            Total: {users.length}
          </div>
        </div>
      </div>

      {/* SORT TOOLBAR (NEW) */}
      <div className="flex justify-end gap-2 mb-4 text-sm">
        <span className="text-text-sub self-center mr-2">Sort by:</span>
        <button onClick={() => handleSort('deposits')} className={`px-3 py-1.5 rounded-lg border ${sortConfig.key === 'deposits' ? 'bg-white border-primary text-primary' : 'bg-transparent border-transparent text-text-sub hover:bg-white'}`}>
          Deposits <SortIcon column="deposits" />
        </button>
        <button onClick={() => handleSort('volume')} className={`px-3 py-1.5 rounded-lg border ${sortConfig.key === 'volume' ? 'bg-white border-primary text-primary' : 'bg-transparent border-transparent text-text-sub hover:bg-white'}`}>
          Volume <SortIcon column="volume" />
        </button>
        <button onClick={() => handleSort('joined')} className={`px-3 py-1.5 rounded-lg border ${sortConfig.key === 'joined' ? 'bg-white border-primary text-primary' : 'bg-transparent border-transparent text-text-sub hover:bg-white'}`}>
          Date Joined <SortIcon column="joined" />
        </button>
      </div>

      {/* USERS LIST (Rendering 'sortedUsers' instead of 'users') */}
      <div className="flex flex-col gap-4">
        {sortedUsers.map(u => {
          const weightGrams = u.totalRecycled || 0; 
          const volumeLiters = (weightGrams / 1000).toFixed(2);
          const deposits = u.depositCount || 0;
          const displayName = u.name && u.name.trim() !== '' 
            ? u.name 
            : u.email ? u.email.split('@')[0] : 'App User';

          return (
            <div key={u.id} className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 flex flex-col md:flex-row justify-between items-center hover:border-primary/30 transition-colors">
              
              {/* User Info */}
              <div className="flex items-center gap-4 w-full md:w-auto">
                <div className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center text-lg font-bold">
                  {displayName.charAt(0).toUpperCase()}
                </div>
                <div>
                  <h3 className="font-bold text-text-main capitalize">{displayName}</h3>
                  <p className="text-sm text-text-sub">{u.email}</p>
                </div>
              </div>
              
              {/* Stats Columns */}
              <div className="flex gap-8 mt-4 md:mt-0 w-full md:w-auto border-t md:border-none pt-4 md:pt-0 border-gray-100">
                <div className="text-center md:text-right w-24">
                  <p className="text-xs text-text-sub uppercase font-bold">Deposits</p>
                  <p className="font-bold text-text-main">{deposits}</p>
                </div>
                <div className="text-center md:text-right w-24">
                  <p className="text-xs text-text-sub uppercase font-bold">Volume</p>
                  <p className="font-bold text-primary">{volumeLiters} L</p>
                </div>
                <div className="text-center md:text-right w-32 hidden sm:block">
                  <p className="text-xs text-text-sub uppercase font-bold">Joined</p>
                  <p className="font-medium text-text-main text-sm">
                    {u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString('en-GB') : '—'}
                  </p>
                </div>
              </div>
            </div>
          );
        })}
        
        {sortedUsers.length === 0 && (
          <div className="text-center py-12 text-text-sub bg-white rounded-2xl border border-dashed border-gray-200">
            No users found.
          </div>
        )}
      </div>
    </div>
  );
}