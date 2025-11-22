// admin-dashboard/src/App.js

import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { collection, doc, getDoc, onSnapshot, query, updateDoc, where } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { auth, db } from './firebase';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
        if (userDoc.exists()) {
          const userData = userDoc.data();
          if (userData.role === 'admin' || userData.role === 'agent') {
            setUser(currentUser);
            setIsAdmin(true);
          } else {
            await signOut(auth);
            alert('Access denied. Admin or Agent role required.');
          }
        } else {
          await signOut(auth);
        }
      } else {
        setUser(null);
        setIsAdmin(false);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return (
      <>
        <AppStyles />
        <div className="loading-screen">
          <div className="spinner"></div>
          <p>Loading UMinyak Admin Dashboard...</p>
        </div>
      </>
    );
  }

  return (
    <>
      <AppStyles />
      {!user ? <Login /> : <Dashboard user={user} />}
    </>
  );
}

// Login Component
function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      setError('Invalid email or password. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-icon">
          <div className="recycle-icon">♻️</div>
        </div>
        <h1 className="login-title">Welcome to</h1>
        <h2 className="login-subtitle">UMinyak Admin Panel</h2>
        <p className="login-description">Manage your recycling kiosk system</p>
        
        <form onSubmit={handleLogin} className="login-form">
          <div className="form-group">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Email Address"
              required
              className="form-input"
            />
          </div>
          <div className="form-group">
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Password"
              required
              className="form-input"
            />
          </div>
          {error && <div className="error-message">{error}</div>}
          <button type="submit" className="login-button" disabled={isLoading}>
            {isLoading ? 'Signing In...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}

// Dashboard Component
function Dashboard({ user }) {
  const [activePage, setActivePage] = useState('home');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const handleLogout = async () => {
    await signOut(auth);
  };

  return (
    <div className="dashboard-container">
      <Sidebar 
        activePage={activePage} 
        setActivePage={setActivePage}
        sidebarOpen={sidebarOpen}
        setSidebarOpen={setSidebarOpen}
      />
      <div className={`main-content ${sidebarOpen ? 'sidebar-open' : 'sidebar-closed'}`}>
        <Header 
          user={user} 
          handleLogout={handleLogout}
          setSidebarOpen={setSidebarOpen}
          sidebarOpen={sidebarOpen}
        />
        <main className="content-area">
          {activePage === 'home' && <DashboardHome />}
          {activePage === 'kiosks' && <KiosksPage />}
          {activePage === 'tasks' && <TasksPage />}
          {activePage === 'users' && <UsersPage />}
        </main>
      </div>
    </div>
  );
}

// Sidebar Component
function Sidebar({ activePage, setActivePage, sidebarOpen, setSidebarOpen }) {
  const menuItems = [
    { id: 'home', label: 'Dashboard', icon: '📊' },
    { id: 'kiosks', label: 'Kiosk Status', icon: '♻️' },
    { id: 'tasks', label: 'Collection Tasks', icon: '🔄' },
    { id: 'users', label: 'Users', icon: '👥' }
  ];

  return (
    <aside className={`sidebar ${sidebarOpen ? 'open' : 'closed'}`}>
      <div className="sidebar-header">
        <div className="recycle-icon">♻️</div>
        <h2 className="sidebar-title">UMinyak</h2>
        <p className="sidebar-subtitle">Admin Panel</p>
      </div>
      <nav className="sidebar-nav">
        {menuItems.map((item) => (
          <button
            key={item.id}
            className={`nav-item ${activePage === item.id ? 'active' : ''}`}
            onClick={() => {
              setActivePage(item.id);
              if (window.innerWidth <= 768) {
                setSidebarOpen(false);
              }
            }}
          >
            <span className="nav-icon">{item.icon}</span>
            <span className="nav-label">{item.label}</span>
          </button>
        ))}
      </nav>
    </aside>
  );
}

// Header Component
function Header({ user, handleLogout, setSidebarOpen, sidebarOpen }) {
  return (
    <header className="header">
      <button 
        className="hamburger-menu"
        onClick={() => setSidebarOpen(!sidebarOpen)}
      >
        ☰
      </button>
      <div className="header-right">
        <span className="user-email">{user.email}</span>
        <button className="logout-button" onClick={handleLogout}>
          Logout
        </button>
      </div>
    </header>
  );
}

// Dashboard Home Page
function DashboardHome() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalKiosks: 0,
    kiosksNeedingService: 0,
    pendingTasks: 0
  });

  useEffect(() => {
    const unsubUsers = onSnapshot(collection(db, 'users'), (snapshot) => {
      setStats(prev => ({ ...prev, totalUsers: snapshot.size }));
    });

    const unsubKiosks = onSnapshot(collection(db, 'kiosks'), (snapshot) => {
      const total = snapshot.size;
      const needingService = snapshot.docs.filter(doc => doc.data().tankLevel > 80).length;
      setStats(prev => ({ 
        ...prev, 
        totalKiosks: total,
        kiosksNeedingService: needingService
      }));
    });

    const tasksQuery = query(collection(db, 'collection_tasks'), where('status', '==', 'Pending'));
    const unsubTasks = onSnapshot(tasksQuery, (snapshot) => {
      setStats(prev => ({ ...prev, pendingTasks: snapshot.size }));
    });

    return () => {
      unsubUsers();
      unsubKiosks();
      unsubTasks();
    };
  }, []);

  return (
    <div className="page-container">
      <h1 className="page-title">Dashboard Overview</h1>
      <div className="stats-grid">
        <StatCard 
          title="Total Users" 
          value={stats.totalUsers} 
          icon="👥"
        />
        <StatCard 
          title="Total Kiosks" 
          value={stats.totalKiosks} 
          icon="♻️"
        />
        <StatCard 
          title="Needs Service" 
          value={stats.kiosksNeedingService} 
          icon="⚠️"
          alert={stats.kiosksNeedingService > 0}
        />
        <StatCard 
          title="Pending Tasks" 
          value={stats.pendingTasks} 
          icon="📋"
          alert={stats.pendingTasks > 0}
        />
      </div>
    </div>
  );
}

// Stat Card Component
function StatCard({ title, value, icon, alert }) {
  return (
    <div className={`stat-card ${alert ? 'alert' : ''}`}>
      <div className="stat-icon">{icon}</div>
      <div className="stat-content">
        <p className="stat-title">{title}</p>
        <p className="stat-value">{value}</p>
      </div>
    </div>
  );
}

// Kiosks Page
function KiosksPage() {
  const [kiosks, setKiosks] = useState([]);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'kiosks'), (snapshot) => {
      const kioskData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setKiosks(kioskData);
    });

    return () => unsubscribe();
  }, []);

  return (
    <div className="page-container">
      <h1 className="page-title">Kiosk Status</h1>
      <p className="page-subtitle">View live data from all kiosks</p>
      <div className="kiosks-grid">
        {kiosks.map((kiosk) => (
          <KioskCard key={kiosk.id} kiosk={kiosk} />
        ))}
      </div>
      {kiosks.length === 0 && (
        <div className="empty-state">
          <div className="empty-icon">♻️</div>
          <p>No kiosks found</p>
          <span>Add kiosks to your Firestore database</span>
        </div>
      )}
    </div>
  );
}

// Kiosk Card Component
function KioskCard({ kiosk }) {
  const getTankColor = (level) => {
    if (level > 80) return '#ef5350';
    if (level > 50) return '#ffa726';
    return '#8bc9a3';
  };

  const tankColor = getTankColor(kiosk.tankLevel);

  return (
    <div className="kiosk-card">
      <div className="kiosk-header">
        <div className="kiosk-icon">♻️</div>
        <div className="kiosk-info">
          <h3 className="kiosk-name">{kiosk.location}</h3>
          <span className={`status-badge ${kiosk.status.toLowerCase()}`}>
            {kiosk.status}
          </span>
        </div>
      </div>
      <div className="tank-section">
        <div className="tank-label">
          <span>Tank Level</span>
          <span className="tank-percentage">{kiosk.tankLevel}%</span>
        </div>
        <div className="progress-bar">
          <div 
            className="progress-fill" 
            style={{ 
              width: `${kiosk.tankLevel}%`,
              backgroundColor: tankColor
            }}
          ></div>
        </div>
        {kiosk.tankLevel > 80 && (
          <div className="alert-badge">⚠️ Service Required</div>
        )}
      </div>
    </div>
  );
}

// Tasks Page
function TasksPage() {
  const [tasks, setTasks] = useState([]);

  useEffect(() => {
    const tasksQuery = query(collection(db, 'collection_tasks'), where('status', '==', 'Pending'));
    const unsubscribe = onSnapshot(tasksQuery, (snapshot) => {
      const taskData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setTasks(taskData);
    });

    return () => unsubscribe();
  }, []);

  const handleCompleteTask = async (taskId) => {
    try {
      await updateDoc(doc(db, 'collection_tasks', taskId), {
        status: 'Completed',
        completedAt: new Date()
      });
      alert('Task marked as completed!');
    } catch (error) {
      alert('Error completing task: ' + error.message);
    }
  };

  return (
    <div className="page-container">
      <h1 className="page-title">Collection Tasks</h1>
      <p className="page-subtitle">Manage pending collection activities</p>
      <div className="tasks-list">
        {tasks.map((task) => (
          <div key={task.id} className="task-card">
            <div className="task-header">
              <div className="task-icon">🔄</div>
              <div className="task-info">
                <h3>{task.location}</h3>
                <p className="task-meta">Kiosk ID: {task.kioskId}</p>
                <p className="task-time">
                  {task.timestamp?.toDate().toLocaleDateString()} • {task.timestamp?.toDate().toLocaleTimeString()}
                </p>
              </div>
            </div>
            <button 
              className="complete-button"
              onClick={() => handleCompleteTask(task.id)}
            >
              Complete Task
            </button>
          </div>
        ))}
      </div>
      {tasks.length === 0 && (
        <div className="empty-state">
          <div className="empty-icon">✅</div>
          <p>No pending tasks</p>
          <span>All kiosks are serviced!</span>
        </div>
      )}
    </div>
  );
}

// Users Page
function UsersPage() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'users'), (snapshot) => {
      const userData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setUsers(userData);
    });

    return () => unsubscribe();
  }, []);

  return (
    <div className="page-container">
      <h1 className="page-title">Registered Users</h1>
      <p className="page-subtitle">View all registered users</p>
      <div className="users-list">
        {users.map((user) => (
          <div key={user.id} className="user-card">
            <div className="user-avatar">
              <span>👤</span>
            </div>
            <div className="user-info">
              <h3>{user.email}</h3>
              <p className="user-id">ID: {user.id}</p>
            </div>
            <span className={`role-badge ${user.role}`}>
              {user.role}
            </span>
          </div>
        ))}
      </div>
      {users.length === 0 && (
        <div className="empty-state">
          <div className="empty-icon">👥</div>
          <p>No users found</p>
          <span>Users will appear here once registered</span>
        </div>
      )}
    </div>
  );
}

// Styles Component
function AppStyles() {
  return (
    <style>{`
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }

      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', sans-serif;
        background-color: #f5f5f5;
        color: #2d3748;
      }

      /* Loading Screen */
      .loading-screen {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100vh;
        background-color: #2E3440;
        color: white;
      }

      .spinner {
        width: 50px;
        height: 50px;
        border: 4px solid rgba(136, 201, 153, 0.3);
        border-top-color: #88C999;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      }

      @keyframes spin {
        to { transform: rotate(360deg); }
      }

      /* Login Page */
      .login-container {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        background-color: #f5f5f5;
        padding: 20px;
      }

      .login-card {
        background: white;
        border-radius: 24px;
        padding: 50px 40px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
        width: 100%;
        max-width: 400px;
        text-align: center;
      }

      .login-icon {
        margin-bottom: 24px;
      }

      .recycle-icon {
        width: 80px;
        height: 80px;
        margin: 0 auto;
        background-color: #2E3440;
        border-radius: 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 40px;
      }

      .login-title {
        font-size: 1.1rem;
        color: #718096;
        font-weight: 400;
        margin-bottom: 8px;
      }

      .login-subtitle {
        font-size: 1.8rem;
        color: #2d3748;
        font-weight: 700;
        margin-bottom: 8px;
      }

      .login-description {
        color: #a0aec0;
        font-size: 0.95rem;
        margin-bottom: 32px;
      }

      .login-form {
        text-align: left;
      }

      .form-group {
        margin-bottom: 16px;
      }

      .form-input {
        width: 100%;
        padding: 14px 16px;
        border: 2px solid #e2e8f0;
        border-radius: 12px;
        font-size: 1rem;
        transition: all 0.3s;
        background-color: #f7fafc;
      }

      .form-input:focus {
        outline: none;
        border-color: #8bc9a3;
        background-color: white;
      }

      .error-message {
        background-color: #fed7d7;
        color: #c53030;
        padding: 12px;
        border-radius: 12px;
        margin-bottom: 16px;
        font-size: 0.9rem;
      }

      .login-button {
        width: 100%;
        padding: 16px;
        background: #2E3440;
        color: white;
        border: none;
        border-radius: 12px;
        font-size: 1rem;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.3s;
        margin-top: 8px;
      }

      .login-button:hover:not(:disabled) {
        background: #1F2937;
        transform: translateY(-2px);
      }

      .login-button:disabled {
        opacity: 0.6;
        cursor: not-allowed;
      }

      /* Dashboard Layout */
      .dashboard-container {
        display: flex;
        min-height: 100vh;
        background-color: #f5f5f5;
      }

      /* Sidebar */
      .sidebar {
        width: 280px;
        background: #2E3440;
        position: fixed;
        left: 0;
        top: 0;
        height: 100vh;
        transition: transform 0.3s ease;
        z-index: 1000;
        overflow-y: auto;
      }

      .sidebar.closed {
        transform: translateX(-100%);
      }

      .sidebar-header {
        padding: 32px 24px;
        text-align: center;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      }

      .sidebar-logo {
        width: 60px;
        height: 60px;
        margin: 0 auto 16px;
        background-color: #88C999;
        border-radius: 16px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 32px;
      }

      .sidebar-title {
        color: #FFFFFF;
        font-size: 1.5rem;
        font-weight: 700;
        margin-bottom: 4px;
      }

      .sidebar-subtitle {
        color: #9CA3AF;
        font-size: 0.9rem;
      }

      .sidebar-nav {
        padding: 24px 0;
      }

      .nav-item {
        width: 100%;
        display: flex;
        align-items: center;
        padding: 16px 24px;
        border: none;
        background: transparent;
        cursor: pointer;
        transition: all 0.2s;
        color: #D1D5DB;
        font-size: 1rem;
        text-align: left;
        border-left: 4px solid transparent;
      }

      .nav-item:hover {
        background-color: rgba(136, 201, 153, 0.1);
        color: #FFFFFF;
      }

      .nav-item.active {
        background-color: rgba(136, 201, 153, 0.15);
        color: #88C999;
        border-left-color: #88C999;
      }

      .nav-icon {
        font-size: 1.4rem;
        margin-right: 16px;
      }

      .nav-label {
        font-weight: 500;
      }

      /* Main Content */
      .main-content {
        flex: 1;
        margin-left: 280px;
        transition: margin-left 0.3s ease;
      }

      .main-content.sidebar-closed {
        margin-left: 0;
      }

      /* Header */
      .header {
        background: white;
        border-bottom: 1px solid #e2e8f0;
        padding: 16px 32px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        position: sticky;
        top: 0;
        z-index: 100;
      }

      .hamburger-menu {
        display: none;
        background: none;
        border: none;
        font-size: 1.5rem;
        cursor: pointer;
        padding: 8px;
        color: #2E3440;
      }

      .header-right {
        display: flex;
        align-items: center;
        gap: 16px;
      }

      .user-email {
        color: #718096;
        font-size: 0.9rem;
      }

      .logout-button {
        padding: 10px 24px;
        background: #2E3440;
        color: white;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        font-weight: 500;
        transition: all 0.3s;
      }

      .logout-button:hover {
        background: #1F2937;
        transform: translateY(-2px);
      }

      /* Content Area */
      .content-area {
        padding: 32px;
        max-width: 1400px;
        margin: 0 auto;
      }

      .page-container {
        animation: fadeIn 0.3s ease;
      }

      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(20px); }
        to { opacity: 1; transform: translateY(0); }
      }

      .page-title {
        font-size: 2rem;
        margin-bottom: 8px;
        color: #2d3748;
        font-weight: 700;
      }

      .page-subtitle {
        color: #718096;
        font-size: 1rem;
        margin-bottom: 32px;
      }

      /* Stats Grid */
      .stats-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 20px;
        margin-bottom: 32px;
      }

      .stat-card {
        background: white;
        border-radius: 16px;
        padding: 24px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
        display: flex;
        align-items: center;
        gap: 20px;
        transition: all 0.3s;
      }

      .stat-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.1);
      }

      .stat-card.alert {
        background: linear-gradient(135deg, #fff5f5 0%, #fed7d7 100%);
      }

      .stat-icon {
        width: 56px;
        height: 56px;
        background-color: #f7fafc;
        border-radius: 14px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 28px;
      }

      .stat-content {
        flex: 1;
      }

      .stat-title {
        font-size: 0.9rem;
        color: #718096;
        margin-bottom: 8px;
      }

      .stat-value {
        font-size: 2rem;
        font-weight: 700;
        color: #2d3748;
      }

      /* Kiosks Grid */
      .kiosks-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
        gap: 24px;
      }

      .kiosk-card {
        background: white;
        border-radius: 16px;
        padding: 24px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
        transition: all 0.3s;
      }

      .kiosk-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.1);
      }

      .kiosk-header {
        display: flex;
        align-items: center;
        gap: 16px;
        margin-bottom: 24px;
      }

      .kiosk-icon {
        width: 48px;
        height: 48px;
        background-color: #2E3440;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24px;
      }

      .kiosk-info {
        flex: 1;
      }

      .kiosk-name {
        font-size: 1.1rem;
        color: #2d3748;
        font-weight: 600;
        margin-bottom: 6px;
      }

      .status-badge {
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 0.75rem;
        font-weight: 600;
      }

      .status-badge.online {
        background-color: #c6f6d5;
        color: #22543d;
      }

      .status-badge.offline {
        background-color: #fed7d7;
        color: #742a2a;
      }

      .tank-section {
        margin-top: 20px;
      }

      .tank-label {
        display: flex;
        justify-content: space-between;
        margin-bottom: 12px;
        color: #718096;
        font-size: 0.9rem;
      }

      .tank-percentage {
        font-weight: 700;
        color: #2d3748;
        font-size: 1rem;
      }

      .progress-bar {
        width: 100%;
        height: 10px;
        background-color: #f7fafc;
        border-radius: 10px;
        overflow: hidden;
      }

      .progress-fill {
        height: 100%;
        transition: width 0.5s ease, background-color 0.3s ease;
        border-radius: 10px;
      }

      .alert-badge {
        margin-top: 14px;
        padding: 10px;
        background-color: #fff5f5;
        color: #c53030;
        border-radius: 10px;
        font-size: 0.85rem;
        font-weight: 600;
        text-align: center;
        border: 1px solid #fed7d7;
      }

      /* Tasks List */
      .tasks-list {
        display: grid;
        gap: 16px;
      }

      .task-card {
        background: white;
        border-radius: 16px;
        padding: 24px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 20px;
        transition: all 0.3s;
      }

      .task-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(0, 0, 0, 0.1);
      }

      .task-header {
        display: flex;
        align-items: center;
        gap: 16px;
        flex: 1;
      }

      .task-icon {
        width: 48px;
        height: 48px;
        background-color: #2E3440;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24px;
      }

      .task-info h3 {
        font-size: 1.1rem;
        color: #2d3748;
        font-weight: 600;
        margin-bottom: 6px;
      }

      .task-meta {
        color: #718096;
        font-size: 0.85rem;
        margin-bottom: 4px;
      }

      .task-time {
        color: #a0aec0;
        font-size: 0.8rem;
      }

      .complete-button {
        padding: 12px 28px;
        background: #88C999;
        color: white;
        border: none;
        border-radius: 12px;
        cursor: pointer;
        font-weight: 600;
        transition: all 0.3s;
        white-space: nowrap;
      }

      .complete-button:hover {
        background: #6FB088;
        transform: translateY(-2px);
      }

      /* Users List */
      .users-list {
        display: grid;
        gap: 16px;
      }

      .user-card {
        background: white;
        border-radius: 16px;
        padding: 20px 24px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
        display: flex;
        align-items: center;
        gap: 16px;
        transition: all 0.3s;
      }

      .user-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(0, 0, 0, 0.1);
      }

      .user-avatar {
        width: 48px;
        height: 48px;
        background: linear-gradient(135deg, #88C999 0%, #6FB088 100%);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24px;
      }

      .user-info {
        flex: 1;
      }

      .user-info h3 {
        font-size: 1rem;
        color: #2d3748;
        font-weight: 600;
        margin-bottom: 4px;
      }

      .user-id {
        font-family: 'Courier New', monospace;
        font-size: 0.8rem;
        color: #a0aec0;
      }

      .role-badge {
        padding: 6px 16px;
        border-radius: 20px;
        font-size: 0.8rem;
        font-weight: 600;
      }

      .role-badge.admin {
        background-color: #e6fffa;
        color: #234e52;
      }

      .role-badge.agent {
        background-color: #e9d8fd;
        color: #44337a;
      }

      .role-badge.user {
        background-color: #c6f6d5;
        color: #22543d;
      }

      /* Empty State */
      .empty-state {
        padding: 80px 20px;
        text-align: center;
        background: white;
        border-radius: 16px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
      }

      .empty-icon {
        font-size: 64px;
        margin-bottom: 20px;
        opacity: 0.5;
      }

      .empty-state p {
        font-size: 1.2rem;
        color: #2d3748;
        font-weight: 600;
        margin-bottom: 8px;
      }

      .empty-state span {
        color: #a0aec0;
        font-size: 0.95rem;
      }

      /* Mobile Responsive */
      @media (max-width: 768px) {
        .sidebar {
          transform: translateX(-100%);
        }

        .sidebar.open {
          transform: translateX(0);
        }

        .main-content {
          margin-left: 0;
        }

        .hamburger-menu {
          display: block;
        }

        .content-area {
          padding: 20px;
        }

        .page-title {
          font-size: 1.5rem;
        }

        .stats-grid {
          grid-template-columns: 1fr;
        }

        .kiosks-grid {
          grid-template-columns: 1fr;
        }

        .user-email {
          display: none;
        }

        .task-card {
          flex-direction: column;
          align-items: flex-start;
        }

        .complete-button {
          width: 100%;
        }
      }

      @media (max-width: 480px) {
        .login-card {
          padding: 40px 24px;
        }

        .stat-card {
          padding: 20px;
        }

        .stat-icon {
          width: 48px;
          height: 48px;
          font-size: 24px;
        }

        .stat-value {
          font-size: 1.5rem;
        }

        .header {
          padding: 12px 20px;
        }

        .logout-button {
          padding: 8px 16px;
          font-size: 0.9rem;
        }
      }
    `}</style>
  );
}

export default App;