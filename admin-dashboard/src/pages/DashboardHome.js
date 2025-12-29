// src/pages/DashboardHome.js
import React, { useEffect, useState, useMemo } from 'react';
import {
  collection,
  getDocs,
  query,
  where,
  onSnapshot,
  orderBy,
  limit,
  doc,
  updateDoc,
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
    totalKg: 0,
  });
  const [loading, setLoading] = useState(true);

  const [recentDeposits, setRecentDeposits] = useState([]);

  // Chart state
  const [dailyLabels, setDailyLabels] = useState([]);
  const [dailyKg, setDailyKg] = useState([]);
  const [topKiosks, setTopKiosks] = useState([]);

  // Notifications
  const [adminNotifs, setAdminNotifs] = useState([]);
  const [notifTab, setNotifTab] = useState('unread'); // 'unread' | 'all'

  // ----------------------------------------------------
  // 1. SUMMARY STATS
  // ----------------------------------------------------
  useEffect(() => {
    async function fetchStats() {
      try {
        const usersColl = collection(db, 'users');
        const usersQuery = query(usersColl, where('role', '==', 'user'));
        const usersSnap = await getDocs(usersQuery);
        const userCount = usersSnap.size;

        const kiosksColl = collection(db, 'kiosks');
        const kiosksSnap = await getDocs(kiosksColl);
        const kioskCount = kiosksSnap.size;

        const tasksColl = collection(db, 'collectionTasks');
        const tasksQuery = query(tasksColl, where('status', '==', 'pending'));
        const tasksSnap = await getDocs(tasksQuery);
        const pendingCount = tasksSnap.size;

        let totalGrams = 0;
        usersSnap.forEach((docx) => {
          const data = docx.data();
          const g = Number(data.totalRecycled);
          if (Number.isFinite(g)) totalGrams += g;
        });

        const totalKg = Number((totalGrams / 1000).toFixed(2));

        setStats({
          users: userCount,
          kiosks: kioskCount,
          tasks: pendingCount,
          totalKg,
        });
      } catch (e) {
        console.error('Error loading stats:', e);
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
    const q = query(collection(db, 'deposits'), orderBy('timestamp', 'desc'), limit(5));

    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((docx) => {
        const data = docx.data();

        let ts = null;
        if (data.timestamp && typeof data.timestamp.toDate === 'function') {
          ts = data.timestamp.toDate();
        }

        const grams = Number(data.weight);
        const weightKg = (Number.isFinite(grams) ? grams : 0) / 1000;

        return {
          id: docx.id,
          kioskName: data.kioskName || data.kioskId || 'Unknown Kiosk',
          userId: data.userId || 'N/A',
          weightKg,
          timestamp: ts,
        };
      });

      setRecentDeposits(list);
    });

    return () => unsub();
  }, []);

  // ----------------------------------------------------
  // 3. ANALYTICS: DAILY WEIGHT + TOP KIOSKS
  // ----------------------------------------------------
  useEffect(() => {
    const q = query(collection(db, 'deposits'), orderBy('timestamp', 'desc'), limit(500));

    const unsub = onSnapshot(q, (snap) => {
      const deposits = snap.docs.map((docx) => {
        const data = docx.data();

        let ts = null;
        if (data.timestamp && typeof data.timestamp.toDate === 'function') {
          ts = data.timestamp.toDate();
        }

        const grams = Number(data.weight);
        const weightKg = (Number.isFinite(grams) ? grams : 0) / 1000;
        const kioskName = data.kioskName || data.kioskId || 'Unknown Kiosk';

        return { ts, weightKg, kioskName };
      });

      // DAILY WEIGHT (last 7 days)
      const today = new Date();
      const dateKeys = [];
      const labelList = [];
      const dailyMap = {};

      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(today.getDate() - i);

        const key = d.toISOString().slice(0, 10);
        const label = d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });

        dateKeys.push(key);
        labelList.push(label);
        dailyMap[key] = 0;
      }

      deposits.forEach((dep) => {
        if (!dep.ts) return;
        const key = dep.ts.toISOString().slice(0, 10);
        if (dailyMap[key] !== undefined) {
          dailyMap[key] += dep.weightKg;
        }
      });

      const kgList = dateKeys.map((k) => Number((dailyMap[k] || 0).toFixed(3)));

      setDailyLabels(labelList);
      setDailyKg(kgList);

      // TOP KIOSKS
      const kioskMap = {};
      deposits.forEach((dep) => {
        if (!dep.weightKg) return;
        kioskMap[dep.kioskName] = (kioskMap[dep.kioskName] || 0) + dep.weightKg;
      });

      const sorted = Object.entries(kioskMap).sort((a, b) => b[1] - a[1]).slice(0, 5);
      setTopKiosks(sorted);
    });

    return () => unsub();
  }, []);

  // ----------------------------------------------------
  // 4. ADMIN NOTIFICATIONS
  // ----------------------------------------------------
  useEffect(() => {
    const base = collection(db, 'adminNotifications');

    const qNotif =
      notifTab === 'unread'
        ? query(base, where('read', '==', false), orderBy('createdAt', 'desc'), limit(10))
        : query(base, orderBy('createdAt', 'desc'), limit(20));

    const unsub = onSnapshot(qNotif, (snap) => {
      const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      setAdminNotifs(list);
    });

    return () => unsub();
  }, [notifTab]);

  // For the badge text
  const unreadCount = useMemo(() => adminNotifs.filter((n) => n.read === false).length, [adminNotifs]);

  if (loading) {
    return <div className="p-8 text-center text-gray-500">Loading live data...</div>;
  }

  return (
    <div>
      <h1 className="text-3xl font-bold text-text-main mb-2">Overview</h1>
      <p className="text-text-sub mb-8">Live data from your recycling network.</p>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          icon="♻️"
          label="Total Recycled"
          value={`${Number(stats.totalKg || 0).toFixed(2)} kg`}
          color="bg-primary"
        />
        <StatCard icon="👥" label="Registered Users" value={stats.users} color="bg-blue-500" />
        <StatCard icon="📍" label="Active Kiosks" value={stats.kiosks} color="bg-orange-500" />
        <StatCard icon="🚛" label="Pending Tasks" value={stats.tasks} color="bg-red-500" />
      </div>

      {/* Notifications */}
      <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100 mb-8">
        {/* ✅ FIXED HEADER LAYOUT */}
        <div className="flex items-center justify-between gap-4 mb-4">
          <div>
            <h2 className="text-xl font-bold text-text-main">Notifications</h2>
            <p className="text-xs text-text-sub mt-0.5">Task completion updates (live)</p>
          </div>

          <div className="flex items-center gap-3">
            {/* Count pill */}
            <div className="text-xs font-semibold px-3 py-1.5 rounded-full border border-gray-200 bg-gray-50 text-gray-700">
              {notifTab === 'unread'
                ? `${adminNotifs.length} unread`
                : `${adminNotifs.length} total${unreadCount > 0 ? ` • ${unreadCount} unread` : ''}`}
            </div>

            {/* Toggle group */}
            <div className="flex rounded-xl border border-gray-200 bg-white p-1">
              <button
                onClick={() => setNotifTab('unread')}
                className={`text-xs font-semibold px-3 py-1.5 rounded-lg transition ${
                  notifTab === 'unread' ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-50'
                }`}
              >
                Unread
              </button>
              <button
                onClick={() => setNotifTab('all')}
                className={`text-xs font-semibold px-3 py-1.5 rounded-lg transition ${
                  notifTab === 'all' ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-50'
                }`}
              >
                All
              </button>
            </div>
          </div>
        </div>

        {adminNotifs.length === 0 ? (
          <p className="text-sm text-text-sub">
            {notifTab === 'unread' ? 'No new notifications.' : 'No notifications yet.'}
          </p>
        ) : (
          <div className="space-y-3">
            {adminNotifs.map((n) => {
              const isRead = n.read === true;

              return (
                <div
                  key={n.id}
                  className={`relative p-4 rounded-xl flex items-start justify-between border ${
                    isRead ? 'bg-gray-50 border-gray-200' : 'bg-green-100/70 border-green-300'
                  }`}
                >
                  <div className={`absolute left-0 top-0 h-full w-1 rounded-l-xl ${isRead ? 'bg-gray-300' : 'bg-green-500'}`} />

                  <div className="pr-4">
                    <p className={`font-semibold ${isRead ? 'text-gray-800' : 'text-green-700'}`}>
                      ✅ Task Completed — {n.kioskName || n.kioskId || 'Unknown Kiosk'}
                    </p>
                    <p className="text-xs text-text-sub mt-1">
                      Agent: {n.agentId || n.agentUid || '—'} • Task ID:{' '}
                      {n.taskId ? String(n.taskId).slice(0, 10) + '…' : '—'}
                    </p>
                  </div>

                  <button
                    onClick={async () => {
                      try {
                        await updateDoc(doc(db, 'adminNotifications', n.id), { read: true });
                      } catch (e) {
                        console.error('Failed to mark as read', e);
                      }
                    }}
                    disabled={isRead}
                    className={`text-xs font-semibold px-3 py-2 rounded-lg border transition ${
                      isRead
                        ? 'bg-white border-gray-200 text-gray-400 cursor-not-allowed'
                        : 'bg-white border-gray-200 hover:bg-gray-50'
                    }`}
                  >
                    {isRead ? 'Read' : 'Mark read'}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
          <h2 className="text-lg font-bold mb-4">Daily Weight (Last 7 Days)</h2>
          <Line
            data={{
              labels: dailyLabels,
              datasets: [
                {
                  label: 'kg Recycled',
                  data: dailyKg,
                  borderColor: '#22c55e',
                  backgroundColor: 'rgba(34, 197, 94, 0.15)',
                  tension: 0.3,
                  pointRadius: 3,
                },
              ],
            }}
            options={{
              responsive: true,
              plugins: { legend: { display: false } },
              scales: {
                y: {
                  beginAtZero: true,
                  ticks: { callback: (value) => `${value} kg` },
                },
              },
            }}
          />
        </div>

        <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
          <h2 className="text-lg font-bold mb-4">Top Kiosks (by Weight)</h2>
          {topKiosks.length === 0 ? (
            <p className="text-sm text-text-sub">Not enough data yet.</p>
          ) : (
            <Bar
              data={{
                labels: topKiosks.map((k) => k[0]),
                datasets: [
                  {
                    label: 'kg',
                    data: topKiosks.map((k) => Number((k[1] || 0).toFixed(3))),
                    backgroundColor: 'rgba(59, 130, 246, 0.6)',
                  },
                ],
              }}
              options={{
                responsive: true,
                plugins: { legend: { display: false } },
                scales: {
                  y: {
                    beginAtZero: true,
                    ticks: { callback: (value) => `${value} kg` },
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
          <p className="text-xs text-text-sub">Last {recentDeposits.length} deposits (live)</p>
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
                  <th className="px-3 py-2 font-medium text-right">Weight (kg)</th>
                </tr>
              </thead>
              <tbody>
                {recentDeposits.map((d) => (
                  <tr key={d.id} className="border-b last:border-0">
                    <td className="px-3 py-2 text-sm text-text-main">
                      {d.timestamp ? d.timestamp.toLocaleString('en-GB') : '—'}
                    </td>
                    <td className="px-3 py-2 text-sm text-text-main">{d.kioskName}</td>
                    <td className="px-3 py-2 text-sm text-text-sub">
                      {d.userId.length > 12 ? d.userId.slice(0, 12) + '…' : d.userId}
                    </td>
                    <td className="px-3 py-2 text-right font-semibold text-primary">
                      {Number(d.weightKg || 0).toFixed(3)} kg
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
        <h2 className="text-xl font-bold text-text-main mb-4">System Status</h2>
        <p className="text-text-sub text-sm">
          The system is active. Kiosk fill levels are being monitored in real-time.
        </p>
      </div>
    </div>
  );
}

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
