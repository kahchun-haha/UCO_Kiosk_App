import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc, getDocs, collection, query, where } from 'firebase/firestore';
import { auth, db } from './firebase';
import Sidebar from './components/Sidebar';
import DashboardHome from './pages/DashboardHome';
import UsersPage from './pages/UsersPage';
import AgentsPage from './pages/AgentsPage';
import AdminsPage from './pages/AdminsPage';
import KiosksPage from './pages/KiosksPage';
import TasksPage from './pages/TasksPage';
import Login from './pages/Login';
import SetupSuperAdmin from './pages/SetupSuperAdmin';

function App(){
  const [user, setUser] = useState(null);
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [hasSuperAdmin, setHasSuperAdmin] = useState(null);

  useEffect(()=>{
    (async ()=>{
      try {
        const q = query(collection(db, 'users'), where('role', '==', 'superadmin'));
        const snaps = await getDocs(q);
        setHasSuperAdmin(!snaps.empty);
      } catch(e) {
        console.error('Error checking superadmin', e);
        setHasSuperAdmin(true);
      }
    })();
  },[]);

  useEffect(()=>{
    const unsub = onAuthStateChanged(auth, async (u)=>{
      if(u){
        setUser(u);
        try{
          const snap = await getDoc(doc(db, 'users', u.uid));
          if(snap.exists()) setUserData(snap.data());
          else setUserData({ role: 'user' });
        }catch(e){
          console.error('fetch user doc', e);
          setUserData({ role: 'user' });
        }
      } else {
        setUser(null);
        setUserData(null);
      }
      setLoading(false);
    });
    return () => unsub();
  },[]);

  if(loading || hasSuperAdmin === null) return <div className="min-h-screen flex items-center justify-center">Loading...</div>;

  // If no superadmin exists, show setup page (one-time)
  if(!hasSuperAdmin){
    return <SetupSuperAdmin onCreated={()=>setHasSuperAdmin(true)} />;
  }

  if(!user) return <Login />;

  const role = userData?.role || 'user';

return (
    <Router>
      <div className="flex min-h-screen bg-background font-sans"> {/* Applied mobile font/bg */}
        <Sidebar role={role} onLogout={()=>signOut(auth)} />
        
        {/* Main Content Area */}
        <main className="flex-1 p-8 overflow-y-auto h-screen">
          <div className="max-w-7xl mx-auto">
            <Routes>
              {/* ... your existing routes ... */}
              <Route path="/" element={<DashboardHome />} />
              <Route path="/users" element={<UsersPage />} />
              <Route path="/agents" element={(role === 'admin' || role === 'superadmin') ? <AgentsPage /> : <Navigate to="/" />} />
              <Route path="/admins" element={(role === 'superadmin') ? <AdminsPage /> : <Navigate to="/" />} />
              <Route path="/kiosks" element={<KiosksPage />} />
              <Route path="/tasks" element={<TasksPage />} />
              <Route path="*" element={<Navigate to="/" />} />
            </Routes>
          </div>
        </main>
      </div>
    </Router>
  );
}

export default App;