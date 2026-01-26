// src/pages/AnalyticsPage.js
import React, { useEffect, useState } from 'react';
import { collection, query, where, orderBy, getDocs } from 'firebase/firestore';
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

export default function AnalyticsPage() {
  // ✅ default = all time
  const [range, setRange] = useState('all'); // 7d, 30d, all
  const [loading, setLoading] = useState(true);

  // Deposits analytics
  const [dailyLabels, setDailyLabels] = useState([]);
  const [dailyKg, setDailyKg] = useState([]);
  const [kioskKg, setKioskKg] = useState([]);
  const [summary, setSummary] = useState({
    totalKg: 0,
    deposits: 0,
    avgKgPerDeposit: 0,
    kiosks: 0, // active kiosks in selected range (based on deposits)
  });

  // Online kiosks (current)
  const [onlineKiosks, setOnlineKiosks] = useState(0);

  // Tasks analytics
  const [taskSummary, setTaskSummary] = useState({
    totalTasks: 0,
    completedTasks: 0,
    avgHours: 0,
  });
  const [tasksByAgent, setTasksByAgent] = useState([]);

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      try {
        // =========================
        // 0) Online Kiosks (current)
        // =========================
        const kiosksOnlineQ = query(collection(db, 'kiosks'), where('status', '==', 'online'));
        const kiosksOnlineSnap = await getDocs(kiosksOnlineQ);
        setOnlineKiosks(kiosksOnlineSnap.size);

        // =========================
        // Build time filter
        // =========================
        let start = null;
        if (range === '7d' || range === '30d') {
          const now = new Date();
          start = new Date();
          if (range === '7d') start.setDate(now.getDate() - 7);
          if (range === '30d') start.setDate(now.getDate() - 30);
        }

        // =========================
        // 1) Deposits
        // =========================
        const depositsBase = collection(db, 'deposits');

        const depositsQ =
          range === 'all'
            ? query(depositsBase, orderBy('timestamp', 'asc'))
            : query(depositsBase, where('timestamp', '>=', start), orderBy('timestamp', 'asc'));

        const depSnap = await getDocs(depositsQ);

        const deps = [];
        depSnap.forEach((docx) => {
          const data = docx.data();
          if (!data.timestamp || typeof data.timestamp.toDate !== 'function') return;

          const ts = data.timestamp.toDate();
          const grams = Number(data.weight);
          const weightKg = (Number.isFinite(grams) ? grams : 0) / 1000;

          deps.push({
            ts,
            weightKg,
            kiosk: data.kioskName || data.kioskId || 'Unknown kiosk',
          });
        });

        // Summary
        const totalKg = deps.reduce((sum, d) => sum + d.weightKg, 0);
        const depositsCount = deps.length;
        const avgKgPerDeposit = depositsCount ? totalKg / depositsCount : 0;
        const kioskSet = new Set(deps.map((d) => d.kiosk));

        setSummary({
          totalKg: Number(totalKg.toFixed(2)),
          deposits: depositsCount,
          avgKgPerDeposit: Number(avgKgPerDeposit.toFixed(2)),
          kiosks: kioskSet.size,
        });

        // DAILY chart:
        // - for 7d/30d => daily is meaningful
        // - for all-time => it can be too many points; we’ll still show daily (your choice)
        const dailyMap = {};
        deps.forEach((d) => {
          const key = d.ts.toISOString().slice(0, 10);
          dailyMap[key] = (dailyMap[key] || 0) + d.weightKg;
        });

        const sortedDays = Object.keys(dailyMap).sort();
        setDailyLabels(
          sortedDays.map((k) =>
            new Date(k).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })
          )
        );
        setDailyKg(sortedDays.map((k) => Number((dailyMap[k] || 0).toFixed(3))));

        // Kiosk chart (kg)
        const kioskMap = {};
        deps.forEach((d) => {
          kioskMap[d.kiosk] = (kioskMap[d.kiosk] || 0) + d.weightKg;
        });

        const kioskEntries = Object.entries(kioskMap).sort((a, b) => b[1] - a[1]);
        setKioskKg(
          kioskEntries.map(([name, kg]) => ({
            name,
            kg: Number((kg || 0).toFixed(3)),
          }))
        );

        // =========================
        // 2) Collection Tasks
        // =========================
        const tasksBase = collection(db, 'collectionTasks');

        const tasksQ =
          range === 'all'
            ? query(tasksBase, orderBy('createdAt', 'asc'))
            : query(tasksBase, where('createdAt', '>=', start), orderBy('createdAt', 'asc'));

        const taskSnap = await getDocs(tasksQ);

        const tasks = [];
        taskSnap.forEach((docx) => {
          const t = docx.data();

          const createdAt =
            t.createdAt && typeof t.createdAt.toDate === 'function' ? t.createdAt.toDate() : null;

          const completedAt =
            t.completedAt && typeof t.completedAt.toDate === 'function'
              ? t.completedAt.toDate()
              : null;

          tasks.push({
            id: docx.id,
            agentId: t.agentId || null,
            status: t.status || 'unknown',
            createdAt,
            completedAt,
          });
        });

        const byAgent = {};
        tasks.forEach((t) => {
          const key = t.agentId || 'Unassigned';
          byAgent[key] = (byAgent[key] || 0) + 1;
        });

        const byAgentSorted = Object.entries(byAgent)
          .sort((a, b) => b[1] - a[1])
          .map(([name, count]) => ({ name, count }));

        setTasksByAgent(byAgentSorted);

        const completed = tasks.filter(
          (t) => t.createdAt && t.completedAt && t.completedAt >= t.createdAt
        );

        let avgHours = 0;
        if (completed.length) {
          const totalMs = completed.reduce(
            (sum, t) => sum + (t.completedAt.getTime() - t.createdAt.getTime()),
            0
          );
          avgHours = totalMs / completed.length / (1000 * 60 * 60);
        }

        setTaskSummary({
          totalTasks: tasks.length,
          completedTasks: completed.length,
          avgHours: Number(avgHours.toFixed(2)),
        });
      } catch (e) {
        console.error('Analytics error:', e);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [range]);

  // Export CSV
  const exportAnalyticsCSV = () => {
    const header = ['Metric', 'Value'];
    const escape = (v) => `"${String(v).replace(/"/g, '""')}"`;

    const rows = [
      ['Range', range],
      ['Total UCO (kg)', summary.totalKg],
      ['Deposits', summary.deposits],
      ['Avg per Deposit (kg)', summary.avgKgPerDeposit],
      ['Active Kiosks (Range)', summary.kiosks],
      ['Online Kiosks (Current)', onlineKiosks],
      ['Total Tasks', taskSummary.totalTasks],
      ['Completed Tasks', taskSummary.completedTasks],
      ['Avg Collection Time (hrs)', taskSummary.avgHours],
      ['', ''],
      ['Tasks per Agent', ''],
      ...tasksByAgent.map((a) => [a.name, a.count]),
    ];

    const csv = [header, ...rows].map((r) => r.map(escape).join(',')).join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const dateStr = new Date().toISOString().slice(0, 10);
    a.download = `analytics_${range}_${dateStr}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">Analytics</h2>
          <p className="text-text-sub text-sm mt-2">Deeper insights into recycling activity.</p>
        </div>

        <div className="flex gap-3">
          <select
            value={range}
            onChange={(e) => setRange(e.target.value)}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 bg-white shadow-sm"
          >
            <option value="all">All time</option>
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
          </select>

          <button
            onClick={exportAnalyticsCSV}
            className="text-sm px-4 py-2 rounded-xl bg-primary text-white font-semibold shadow-md shadow-primary/30 hover:bg-primary/90 transition-colors"
          >
            Export Report CSV
          </button>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-6 gap-4 mb-6">
        <SummaryCard label="Total Weight" value={`${Number(summary.totalKg || 0).toFixed(2)} kg`} />
        <SummaryCard label="Deposits" value={summary.deposits} />
        <SummaryCard
          label="Avg per Deposit"
          value={`${Number(summary.avgKgPerDeposit || 0).toFixed(2)} kg`}
        />
        <SummaryCard label="Online Kiosks" value={onlineKiosks} />
        <SummaryCard label="Total Tasks" value={taskSummary.totalTasks} />
        <SummaryCard label="Avg Collection Time" value={`${taskSummary.avgHours} hrs`} />
      </div>

      {loading ? (
        <div className="p-8 text-center text-text-sub">Loading analytics…</div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Daily weight */}
          <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-lg font-bold text-text-main mb-4">
              Daily Weight {range === 'all' ? '(All time)' : range === '7d' ? '(Last 7 days)' : '(Last 30 days)'}
            </h3>

            {dailyLabels.length === 0 ? (
              <p className="text-sm text-text-sub">No data for selected range.</p>
            ) : (
              <Line
                data={{
                  labels: dailyLabels,
                  datasets: [
                    {
                      label: 'kg',
                      data: dailyKg,
                      borderColor: '#22c55e',
                      backgroundColor: 'rgba(34,197,94,0.15)',
                      tension: 0.3,
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

          {/* Kiosk weight */}
          <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-lg font-bold text-text-main mb-4">Weight by Kiosk</h3>
            {kioskKg.length === 0 ? (
              <p className="text-sm text-text-sub">No data for selected range.</p>
            ) : (
              <Bar
                data={{
                  labels: kioskKg.map((k) => k.name),
                  datasets: [
                    {
                      label: 'kg',
                      data: kioskKg.map((k) => k.kg),
                      backgroundColor: 'rgba(59,130,246,0.7)',
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

          {/* Tasks per agent */}
          <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100 lg:col-span-2">
            <h3 className="text-lg font-bold text-text-main mb-4">Tasks per Agent</h3>
            {tasksByAgent.length === 0 ? (
              <p className="text-sm text-text-sub">No tasks for selected range.</p>
            ) : (
              <Bar
                data={{
                  labels: tasksByAgent.map((a) => a.name),
                  datasets: [
                    {
                      label: 'Tasks',
                      data: tasksByAgent.map((a) => a.count),
                      backgroundColor: 'rgba(168,85,247,0.65)',
                    },
                  ],
                }}
                options={{
                  responsive: true,
                  plugins: { legend: { display: false } },
                  scales: { y: { beginAtZero: true } },
                }}
              />
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function SummaryCard({ label, value }) {
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 px-5 py-4">
      <p className="text-xs text-text-sub uppercase font-semibold mb-1">{label}</p>
      <p className="text-xl font-bold text-text-main">{value}</p>
    </div>
  );
}
