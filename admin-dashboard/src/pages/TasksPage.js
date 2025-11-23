// src/pages/TasksPage.js
  import React, { useEffect, useState } from 'react';
  import { collection, onSnapshot, query, where, orderBy, updateDoc, doc } from 'firebase/firestore';
  import { db } from '../firebase';

  export default function TasksPage() {
    const [tasks, setTasks] = useState([]);

    useEffect(() => {
      const q = query(collection(db, 'collection_tasks'), orderBy('createdAt','desc'));
      const unsub = onSnapshot(q, (snap) => {
        setTasks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      });
      return () => unsub();
    }, []);

    const markComplete = async (t) => {
      if (!window.confirm('Mark task completed?')) return;
      try {
        await updateDoc(doc(db, 'collection_tasks', t.id), { status: 'completed', completedAt: new Date() });
      } catch (e) {
        console.error(e);
        alert('Failed to update task.');
      }
    };

    return (
      <div className="page">
        <h2>Collection Tasks</h2>
        <div className="list">
          {tasks.map(t => (
            <div key={t.id} className="list-item">
              <div>
                <strong>{t.kioskName || t.kioskId}</strong>
                <div className="muted">Status: {t.status}</div>
              </div>
              <div className="actions">
                {t.status !== 'completed' && <button className="btn" onClick={()=>markComplete(t)}>Mark Completed</button>}
              </div>
            </div>
          ))}
          {tasks.length === 0 && <div className="empty">No tasks found.</div>}
        </div>
      </div>
    );
  }