// src/pages/DashboardHome.js
import React, { useEffect, useState } from 'react';
import {
  collection,
  getDocs,
  query,
  where,
  onSnapshot,
  orderBy,
  limit,
} from 'firebase/firestore';

import { db } from '../firebase';

import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import { Line, Bar } from 'react-chartjs-2';

// Register chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function DashboardHome() {
  const [stats, setStats] = useState({
    users: 0,
    kiosks: 0,
    tasks: 0,
    volume: 0,
  });
  const [loading, setLoading] = useState(true);

  const [recentDeposits, setRecentDeposits] = useState([]);

  // Chart state
  const [dailyLabels, setDailyLabels] = useState([]); // x-axis for daily chart
  const [dailyVolume, setDailyVolume] = useState([]); // liters per day
  const [topKiosks, setTopKiosks] = useState([]); // [ [name, liters], ... ]

// ----------------------------------------------------
  // 1. SUMMARY STATS  (manual counting, no aggregates)
  // ----------------------------------------------------
  useEffect(() => {
    async function fetchStats() {
      try {
        // 1. Users (role === 'user')
        const usersColl = collection(db, 'users');
        const usersQuery = query(usersColl, where('role', '==', 'user'));
        const usersSnap = await getDocs(usersQuery);
        const userCount = usersSnap.size;

        // 2. Kiosks
        const kiosksColl = collection(db, 'kiosks');
        const kiosksSnap = await getDocs(kiosksColl);
        const kioskCount = kiosksSnap.size;

        // 3. Pending tasks
        const tasksColl = collection(db, 'collectionTasks');
        const tasksQuery = query(tasksColl, where('status', '==', 'pending'));
        const tasksSnap = await getDocs(tasksQuery);
        const pendingCount = tasksSnap.size;

        // 4. Total recycled (sum of users.totalRecycled)
        let totalGrams = 0;
        usersSnap.forEach((doc) => {
          const data = doc.data();
          if (typeof data.totalRecycled === 'number') {
            totalGrams += data.totalRecycled;
          }
        });
        const totalLiters = (totalGrams / 1000).toFixed(1);

        setStats({
          users: userCount,
          kiosks: kioskCount,
          tasks: pendingCount,
          volume: totalLiters,
        });
      } catch (e) {
        console.error('Error loading stats:', e);
        // leave defaults if something fails
      } finally {
        setLoading(false);
      }
    }

    fetchStats();
  }, []);


  // ----------------------------------------------------
  // 2. RECENT DEPOSITS (last 5)
  // ----------------------------------------------------
  useEffect(() => {
    const q = query(
      collection(db, 'deposits'),
      orderBy('timestamp', 'desc'),
      limit(5)
    );

    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => {
        const data = doc.data();

        // Safe timestamp conversion
        let ts = null;
        if (data.timestamp && typeof data.timestamp.toDate === 'function') {
          ts = data.timestamp.toDate();
        }

        const weightGrams = data.weight || 0;
        const volumeLiters = (weightGrams / 1000).toFixed(2);

        return {
          id: doc.id,
          kioskName: data.kioskName || data.kioskId || 'Unknown Kiosk',
          userId: data.userId || 'N/A',
          volumeLiters,
          timestamp: ts,
        };
      });

      setRecentDeposits(list);
    });

    return () => unsub();
  }, []);

  // ----------------------------------------------------
  // 3. ANALYTICS: DAILY VOLUME + TOP KIOSKS
  // ----------------------------------------------------
  useEffect(() => {
    const q = query(
      collection(db, 'deposits'),
      orderBy('timestamp', 'desc'),
      limit(500) // enough for last days & kiosks
    );

    const unsub = onSnapshot(q, (snap) => {
      const deposits = snap.docs.map((doc) => {
        const data = doc.data();

        let ts = null;
        if (data.timestamp && typeof data.timestamp.toDate === 'function') {
          ts = data.timestamp.toDate();
        }

        const weight = data.weight || 0;
        const kioskName = data.kioskName || data.kioskId || 'Unknown Kiosk';

        return { ts, weight, kioskName };
      });

      // ---- DAILY VOLUME (last 7 days) ----
      const today = new Date();
      const dateKeys = [];
      const labelList = [];
      const dailyMap = {};

      // Build 7 days: 6 days ago ... today
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(today.getDate() - i);

        const key = d.toISOString().slice(0, 10); // yyyy-mm-dd
        const label = d.toLocaleDateString('en-GB', {
          day: '2-digit',
          month: 'short',
        });

        dateKeys.push(key);
        labelList.push(label);
        dailyMap[key] = 0;
      }

      deposits.forEach((dep) => {
        if (!dep.ts) return;
        const key = dep.ts.toISOString().slice(0, 10);
        if (dailyMap[key] !== undefined) {
          dailyMap[key] += dep.weight / 1000; // grams → liters
        }
      });

      const volumeList = dateKeys.map((k) =>
        Number(dailyMap[k].toFixed(2))
      );

      setDailyLabels(labelList);
      setDailyVolume(volumeList);

      // ---- TOP KIOSKS BY TOTAL VOLUME ----
      const kioskMap = {};
      deposits.forEach((dep) => {
        if (!dep.weight) return;
        kioskMap[dep.kioskName] =
          (kioskMap[dep.kioskName] || 0) + dep.weight / 1000;
      });

      const sorted = Object.entries(kioskMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);

      setTopKiosks(sorted);
    });

    return () => unsub();
  }, []);

  // ----------------------------------------------------
  // RENDER
  // ----------------------------------------------------
  if (loading) {
    return (
      <div className="p-8 text-center text-gray-500">
        Loading live data...
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-3xl font-bold text-text-main mb-2">Overview</h1>
      <p className="text-text-sub mb-8">
        Live data from your recycling network.
      </p>

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

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Daily Volume Chart */}
        <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
          <h2 className="text-lg font-bold mb-4">Daily Volume (Last 7 Days)</h2>
          <Line
            data={{
              labels: dailyLabels,
              datasets: [
                {
                  label: 'Liters Recycled',
                  data: dailyVolume,
                  borderColor: '#22c55e',
                  backgroundColor: 'rgba(34, 197, 94, 0.15)',
                  tension: 0.3,
                  pointRadius: 3,
                },
              ],
            }}
            options={{
              responsive: true,
              plugins: {
                legend: { display: false },
              },
              scales: {
                y: {
                  beginAtZero: true,
                  ticks: {
                    callback: (value) => `${value} L`,
                  },
                },
              },
            }}
          />
        </div>

        {/* Top Kiosks Chart */}
        <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
          <h2 className="text-lg font-bold mb-4">Top Kiosks (by Volume)</h2>
          {topKiosks.length === 0 ? (
            <p className="text-sm text-text-sub">Not enough data yet.</p>
          ) : (
            <Bar
              data={{
                labels: topKiosks.map((k) => k[0]),
                datasets: [
                  {
                    label: 'Liters',
                    data: topKiosks.map((k) =>
                      Number(k[1].toFixed(2))
                    ),
                    backgroundColor: 'rgba(59, 130, 246, 0.6)',
                  },
                ],
              }}
              options={{
                responsive: true,
                plugins: {
                  legend: { display: false },
                },
                scales: {
                  y: {
                    beginAtZero: true,
                    ticks: {
                      callback: (value) => `${value} L`,
                    },
                  },
                },
              }}
            />
          )}
        </div>
      </div>

      {/* Recent Deposits */}
      <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100 mb-8">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-bold text-text-main">Recent Deposits</h2>
          <p className="text-xs text-text-sub">
            Last {recentDeposits.length} deposits (live)
          </p>
        </div>

        {recentDeposits.length === 0 ? (
          <p className="text-sm text-text-sub">No deposits found.</p>
        ) : (
          <div className="overflow-x-auto -mx-3">
            <table className="min-w-full text-sm text-left">
              <thead>
                <tr className="text-text-sub border-b">
                  <th className="px-3 py-2 font-medium">Time</th>
                  <th className="px-3 py-2 font-medium">Kiosk</th>
                  <th className="px-3 py-2 font-medium">User</th>
                  <th className="px-3 py-2 font-medium text-right">Volume</th>
                </tr>
              </thead>
              <tbody>
                {recentDeposits.map((d) => (
                  <tr key={d.id} className="border-b last:border-0">
                    <td className="px-3 py-2 text-sm text-text-main">
                      {d.timestamp ? d.timestamp.toLocaleString('en-GB') : '—'}
                    </td>

                    <td className="px-3 py-2 text-sm text-text-main">
                      {d.kioskName}
                    </td>

                    <td className="px-3 py-2 text-sm text-text-sub">
                      {d.userId.length > 12 ? d.userId.slice(0, 12) + '…' : d.userId}
                    </td>

                    <td className="px-3 py-2 text-right font-semibold text-primary">
                      {d.volumeLiters} L
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* System Status */}
      <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
        <h2 className="text-xl font-bold text-text-main mb-4">
          System Status
        </h2>
        <p className="text-text-sub text-sm">
          The system is active. Kiosk fill levels are being monitored in
          real-time.
        </p>
      </div>
    </div>
  );
}

// -----------------------------------------------------
// CARD COMPONENT
// -----------------------------------------------------
function StatCard({ icon, label, value, color }) {
  return (
    <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-start justify-between hover:shadow-md transition-shadow">
      <div>
        <p className="text-text-sub text-sm font-medium mb-1">{label}</p>
        <h3 className="text-2xl font-bold text-text-main">{value}</h3>
      </div>
      <div
        className={`w-12 h-12 rounded-xl ${color} bg-opacity-10 flex items-center justify-center text-2xl`}
      >
        {icon}
      </div>
    </div>
  );
}
