import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { db } from '../firebase';

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  
  useEffect(() => {
    const q = query(collection(db, 'users'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-text-main">Registered Users</h2>
          <p className="text-text-sub text-sm">View details of all app users</p>
        </div>
        <div className="bg-white px-4 py-2 rounded-xl border border-gray-100 text-sm font-medium text-text-main shadow-sm">
          Total: {users.length}
        </div>
      </div>

      <div className="flex flex-col gap-4">
        {users.map(u => (
          <div key={u.id} className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 flex flex-col md:flex-row justify-between items-center hover:border-primary/30 transition-colors">
            <div className="flex items-center gap-4 w-full md:w-auto">
              <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-xl">👤</div>
              <div>
                <h3 className="font-bold text-text-main">{u.name || 'Unknown User'}</h3>
                <p className="text-sm text-text-sub">{u.email}</p>
              </div>
            </div>
            
            <div className="flex gap-8 mt-4 md:mt-0 w-full md:w-auto border-t md:border-none pt-4 md:pt-0 border-gray-100">
              <div className="text-center md:text-right">
                <p className="text-xs text-text-sub uppercase font-bold">Deposits</p>
                <p className="font-bold text-text-main">{u.depositCount || 0}</p>
              </div>
              <div className="text-center md:text-right">
                <p className="text-xs text-text-sub uppercase font-bold">Volume</p>
                <p className="font-bold text-primary">{u.totalVolume || 0} L</p>
              </div>
              <div className="text-center md:text-right hidden sm:block">
                <p className="text-xs text-text-sub uppercase font-bold">Joined</p>
                <p className="font-medium text-text-main text-sm">
                  {u.createdAt ? new Date(u.createdAt.seconds*1000).toLocaleDateString() : '—'}
                </p>
              </div>
            </div>
          </div>
        ))}
        
        {users.length === 0 && (
          <div className="text-center py-12 text-text-sub bg-white rounded-2xl border border-dashed border-gray-200">
            No users found.
          </div>
        )}
      </div>
    </div>
  );
}