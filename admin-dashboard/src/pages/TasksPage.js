import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy, updateDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';

export default function TasksPage() {
  const [tasks, setTasks] = useState([]);

  useEffect(() => {
    const q = query(collection(db, 'collectionTasks'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setTasks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  const markComplete = async (t) => {
    if (!window.confirm('Mark task completed?')) return;
    try {
      await updateDoc(doc(db, 'collectionTasks', t.id), { status: 'completed', completedAt: new Date() });
    } catch (e) {
      console.error(e);
      alert('Failed to update.');
    }
  };

  return (
    <div>
      <h2 className="text-3xl font-bold text-text-main mb-6">Collection Tasks</h2>
      
      <div className="flex flex-col gap-4">
        {tasks.map(t => {
          const isCompleted = t.status === 'completed';
          return (
            <div key={t.id} className={`p-5 rounded-2xl border flex justify-between items-center ${isCompleted ? 'bg-gray-50 border-gray-100 opacity-75' : 'bg-white border-gray-100 shadow-sm'}`}>
              <div className="flex items-start gap-4">
                <div className={`p-3 rounded-xl text-xl ${isCompleted ? 'bg-gray-200 text-gray-500' : 'bg-orange-100 text-orange-500'}`}>
                  {isCompleted ? '✅' : '🚛'}
                </div>
                <div>
                  <h3 className={`font-bold text-lg ${isCompleted ? 'text-gray-500 line-through' : 'text-text-main'}`}>
                    {t.kioskName || t.kioskId}
                  </h3>
                  <div className="flex gap-2 mt-1">
                    <span className={`text-xs px-2 py-0.5 rounded font-medium ${isCompleted ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                      {t.status?.toUpperCase()}
                    </span>
                    {t.createdAt && (
                      <span className="text-xs text-text-sub py-0.5">
                        Created: {new Date(t.createdAt.seconds * 1000).toLocaleDateString('en-GB')}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {!isCompleted && (
                <button 
                  onClick={() => markComplete(t)}
                  className="px-4 py-2 bg-primary text-white rounded-xl text-sm font-semibold hover:bg-opacity-90 shadow-md shadow-primary/30 transition-all"
                >
                  Mark Done
                </button>
              )}
            </div>
          );
        })}
        {tasks.length === 0 && <div className="text-center py-12 text-text-sub">No tasks active.</div>}
      </div>
    </div>
  );
}