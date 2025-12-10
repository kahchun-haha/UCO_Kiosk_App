// src/pages/DepositsPage.js
import React, { useEffect, useState } from 'react';
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  where,
} from 'firebase/firestore';
import { db } from '../firebase';

export default function DepositsPage() {
  const [deposits, setDeposits] = useState([]);
  const [filterKiosk, setFilterKiosk] = useState('all');
  const [filterRange, setFilterRange] = useState('all'); // 7d, 30d, all

  // ---- Live listener ----
  useEffect(() => {
    let q = query(collection(db, 'deposits'), orderBy('timestamp', 'desc'));

    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => {
        const data = doc.data();
        let ts = null;
        if (data.timestamp && typeof data.timestamp.toDate === 'function') {
          ts = data.timestamp.toDate();
        }
        const weight = data.weight || 0;
        return {
          id: doc.id,
          kioskId: data.kioskId || '',
          kioskName: data.kioskName || data.kioskId || 'Unknown kiosk',
          userId: data.userId || 'N/A',
          timestamp: ts,
          weight,
          volumeLiters: (weight / 1000).toFixed(2),
        };
      });
      setDeposits(list);
    });

    return () => unsub();
  }, []);

  // ---- Filters applied in memory (light dataset is fine) ----
  const filtered = deposits.filter((d) => {
    if (filterKiosk !== 'all' && d.kioskId !== filterKiosk) return false;

    if (filterRange !== 'all' && d.timestamp) {
      const now = new Date();
      const diffDays =
        (now.getTime() - d.timestamp.getTime()) / (1000 * 60 * 60 * 24);
      if (filterRange === '7d' && diffDays > 7) return false;
      if (filterRange === '30d' && diffDays > 30) return false;
    }

    return true;
  });

  // Unique kiosks for filter dropdown
  const kioskOptions = Array.from(
    new Map(
      deposits.map((d) => [d.kioskId || d.kioskName, d.kioskName])
    ).entries()
  );

  // ---- CSV Export ----
  const exportCSV = () => {
    if (filtered.length === 0) {
      alert('No deposits to export for current filter.');
      return;
    }

    const header = ['Time', 'Kiosk', 'User', 'Weight (g)', 'Volume (L)'];

    const escape = (value) =>
      `"${String(value).replace(/"/g, '""')}"`; // CSV-safe

    const rows = filtered.map((d) => [
      d.timestamp ? d.timestamp.toISOString() : '',
      d.kioskName,
      d.userId,
      d.weight.toFixed(0),
      d.volumeLiters,
    ]);

    const csvContent =
      [header, ...rows]
        .map((row) => row.map(escape).join(','))
        .join('\r\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const dateStr = new Date().toISOString().slice(0, 10);
    a.download = `deposits_${dateStr}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-3xl font-bold text-text-main mb-1">Deposits</h2>
          <p className="text-text-sub text-sm mt-2">
            All deposit events recorded from kiosks.
          </p>
        </div>

        <div className="flex gap-3">
          {/* Range filter */}
          <select
            value={filterRange}
            onChange={(e) => setFilterRange(e.target.value)}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 bg-white shadow-sm"
          >
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
            <option value="all">All time</option>
          </select>

          {/* Kiosk filter */}
          <select
            value={filterKiosk}
            onChange={(e) => setFilterKiosk(e.target.value)}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 bg-white shadow-sm"
          >
            <option value="all">All kiosks</option>
            {kioskOptions.map(([id, name]) => (
              <option key={id || name} value={id}>
                {name} ({id || 'no-id'})
              </option>
            ))}
          </select>

          {/* Export button */}
          <button
            onClick={exportCSV}
            className="text-sm px-4 py-2 rounded-xl bg-primary text-white font-semibold shadow-md shadow-primary/30 hover:bg-primary/90 transition-colors"
          >
            Export CSV
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-x-auto">
        <table className="min-w-full text-sm text-left">
          <thead>
            <tr className="text-text-sub border-b bg-gray-50/60">
              <th className="px-4 py-2 font-medium">Time</th>
              <th className="px-4 py-2 font-medium">Kiosk</th>
              <th className="px-4 py-2 font-medium">User</th>
              <th className="px-4 py-2 font-medium text-right">Weight (g)</th>
              <th className="px-4 py-2 font-medium text-right">Volume (L)</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((d) => (
              <tr key={d.id} className="border-b last:border-0">
                <td className="px-4 py-2 text-text-main">
                  {d.timestamp
                    ? d.timestamp.toLocaleString('en-GB')
                    : '—'}
                </td>
                <td className="px-4 py-2 text-text-main">{d.kioskName}</td>
                <td className="px-4 py-2 text-text-sub text-xs">
                  {d.userId.length > 14
                    ? d.userId.slice(0, 14) + '…'
                    : d.userId}
                </td>
                <td className="px-4 py-2 text-right text-text-main">
                  {d.weight.toFixed(0)}
                </td>
                <td className="px-4 py-2 text-right font-semibold text-primary">
                  {d.volumeLiters}
                </td>
              </tr>
            ))}

            {filtered.length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-6 text-center text-text-sub"
                >
                  No deposits match current filter.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
