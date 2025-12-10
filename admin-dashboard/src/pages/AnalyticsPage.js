import React, { useEffect, useState } from 'react';
import {
  collection,
  query,
  where,
  orderBy,
  getDocs,
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

export default function AnalyticsPage() {
  const [range, setRange] = useState('30d'); // 7d, 30d, 90d
  const [loading, setLoading] = useState(true);
  const [dailyLabels, setDailyLabels] = useState([]);
  const [dailyVolume, setDailyVolume] = useState([]);
  const [kioskVolume, setKioskVolume] = useState([]);
  const [summary, setSummary] = useState({
    totalLiters: 0,
    deposits: 0,
    avgPerDeposit: 0,
    kiosks: 0,
  });

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      try {
        const now = new Date();
        const start = new Date();
        if (range === '7d') start.setDate(now.getDate() - 7);
        else if (range === '30d') start.setDate(now.getDate() - 30);
        else if (range === '90d') start.setDate(now.getDate() - 90);

        const q = query(
          collection(db, 'deposits'),
          where('timestamp', '>=', start),
          orderBy('timestamp', 'asc')
        );

        const snap = await getDocs(q);
        const deps = [];

        snap.forEach((doc) => {
          const data = doc.data();
          if (!data.timestamp || typeof data.timestamp.toDate !== 'function')
            return;
          const ts = data.timestamp.toDate();
          const weight = data.weight || 0;
          deps.push({
            ts,
            weight,
            kiosk: data.kioskName || data.kioskId || 'Unknown kiosk',
          });
        });

        // summary
        const totalGrams = deps.reduce((sum, d) => sum + d.weight, 0);
        const totalLiters = totalGrams / 1000;
        const depositsCount = deps.length;
        const avgPerDeposit = depositsCount
          ? totalLiters / depositsCount
          : 0;
        const kioskSet = new Set(deps.map((d) => d.kiosk));

        setSummary({
          totalLiters: totalLiters.toFixed(2),
          deposits: depositsCount,
          avgPerDeposit: avgPerDeposit.toFixed(2),
          kiosks: kioskSet.size,
        });

        // daily chart
        const dailyMap = {};
        deps.forEach((d) => {
          const key = d.ts.toISOString().slice(0, 10);
          dailyMap[key] = (dailyMap[key] || 0) + d.weight / 1000;
        });

        const sortedDays = Object.keys(dailyMap).sort();
        setDailyLabels(
          sortedDays.map((k) =>
            new Date(k).toLocaleDateString('en-GB', {
              day: '2-digit',
              month: 'short',
            })
          )
        );
        setDailyVolume(sortedDays.map((k) => dailyMap[k].toFixed(2)));

        // kiosk chart
        const kioskMap = {};
        deps.forEach((d) => {
          kioskMap[d.kiosk] =
            (kioskMap[d.kiosk] || 0) + d.weight / 1000;
        });
        const kioskEntries = Object.entries(kioskMap).sort(
          (a, b) => b[1] - a[1]
        );
        setKioskVolume(
          kioskEntries.map(([name, liters]) => ({
            name,
            liters: liters.toFixed(2),
          }))
        );
      } catch (e) {
        console.error('Analytics error:', e);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [range]);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">
            Analytics
          </h2>
          <p className="text-text-sub text-sm mt-2">
            Deeper insights into recycling activity.
          </p>
        </div>

        <select
          value={range}
          onChange={(e) => setRange(e.target.value)}
          className="text-sm border border-gray-200 rounded-xl px-3 py-2 bg-white shadow-sm"
        >
          <option value="7d">Last 7 days</option>
          <option value="30d">Last 30 days</option>
          <option value="90d">Last 90 days</option>
        </select>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 mb-6">
        <SummaryCard
          label="Total Volume"
          value={`${summary.totalLiters} L`}
        />
        <SummaryCard
          label="Deposits"
          value={summary.deposits}
        />
        <SummaryCard
          label="Avg per Deposit"
          value={`${summary.avgPerDeposit} L`}
        />
        <SummaryCard
          label="Active Kiosks"
          value={summary.kiosks}
        />
      </div>

      {loading ? (
        <div className="p-8 text-center text-text-sub">
          Loading analytics…
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Daily volume */}
          <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-lg font-bold text-text-main mb-4">
              Daily Volume
            </h3>
            {dailyLabels.length === 0 ? (
              <p className="text-sm text-text-sub">
                No data for selected range.
              </p>
            ) : (
              <Line
                data={{
                  labels: dailyLabels,
                  datasets: [
                    {
                      label: 'Liters',
                      data: dailyVolume,
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
                    y: { beginAtZero: true },
                  },
                }}
              />
            )}
          </div>

          {/* Kiosk volume */}
          <div className="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-lg font-bold text-text-main mb-4">
              Volume by Kiosk
            </h3>
            {kioskVolume.length === 0 ? (
              <p className="text-sm text-text-sub">
                No data for selected range.
              </p>
            ) : (
              <Bar
                data={{
                  labels: kioskVolume.map((k) => k.name),
                  datasets: [
                    {
                      label: 'Liters',
                      data: kioskVolume.map((k) => k.liters),
                      backgroundColor: 'rgba(59,130,246,0.7)',
                    },
                  ],
                }}
                options={{
                  responsive: true,
                  plugins: { legend: { display: false } },
                  scales: {
                    y: { beginAtZero: true },
                  },
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
      <p className="text-xs text-text-sub uppercase font-semibold mb-1">
        {label}
      </p>
      <p className="text-xl font-bold text-text-main">{value}</p>
    </div>
  );
}
