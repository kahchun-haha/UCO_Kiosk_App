import { collection, getAggregateFromServer, getCountFromServer, query, sum, where } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { db } from '../firebase';

export default function DashboardHome() {
  const [stats, setStats] = useState({
    users: 0,
    kiosks: 0,
    tasks: 0,
    volume: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchStats() {
      try {
        // 1. Count Users
        const usersColl = collection(db, 'users');
        const usersSnap = await getCountFromServer(query(usersColl, where('role', '==', 'user')));
        
        // 2. Count Kiosks
        const kiosksColl = collection(db, 'kiosks');
        const kiosksSnap = await getCountFromServer(kiosksColl);

        // 3. Count Pending Tasks
        const tasksColl = collection(db, 'collection_tasks'); // Note: snake_case matches your rules
        const tasksSnap = await getCountFromServer(query(tasksColl, where('status', '==', 'pending')));

        // 4. Sum Total Volume (Optional: Sum 'totalVolume' from users)
        // This calculates the sum of the 'totalVolume' field across all users
        const volumeSnap = await getAggregateFromServer(usersColl, {
          totalVol: sum('totalVolume')
        });

        setStats({
          users: usersSnap.data().count,
          kiosks: kiosksSnap.data().count,
          tasks: tasksSnap.data().count,
          volume: volumeSnap.data().totalVol || 0
        });
      } catch (e) {
        console.error("Error fetching stats:", e);
      } finally {
        setLoading(false);
      }
    }

    fetchStats();
  }, []);

  if (loading) return <div className="p-8 text-center text-gray-500">Loading live data...</div>;

  return (
    <div>
      <h1 className="text-3xl font-bold text-text-main mb-2">Overview</h1>
      <p className="text-text-sub mb-8">Live data from your recycling network.</p>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard 
          icon="♻️" 
          label="Total Recycled" 
          value={`${stats.volume} L`} 
          color="bg-primary" 
        />
        <StatCard 
          icon="👥" 
          label="Registered Users" 
          value={stats.users} 
          color="bg-blue-500" 
        />
        <StatCard 
          icon="📍" 
          label="Active Kiosks" 
          value={stats.kiosks} 
          color="bg-orange-500" 
        />
        <StatCard 
          icon="🚛" 
          label="Pending Tasks" 
          value={stats.tasks} 
          color="bg-red-500" 
        />
      </div>

      {/* Simple Activity Section */}
      <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
        <h2 className="text-xl font-bold text-text-main mb-4">System Status</h2>
        <p className="text-text-sub text-sm">
          The system is active. Kiosk fill levels are being monitored in real-time.
        </p>
      </div>
    </div>
  );
}

// Helper Component
function StatCard({ icon, label, value, color }) {
  return (
    <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-start justify-between hover:shadow-md transition-shadow">
      <div>
        <p className="text-text-sub text-sm font-medium mb-1">{label}</p>
        <h3 className="text-2xl font-bold text-text-main">{value}</h3>
      </div>
      <div className={`w-12 h-12 rounded-xl ${color} bg-opacity-10 flex items-center justify-center text-2xl`}>
        {icon}
      </div>
    </div>
  );
}