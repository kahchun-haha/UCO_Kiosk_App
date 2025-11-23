// src/pages/DashboardHome.js
  import React from 'react';

  export default function DashboardHome() {
    return (
      <div className="page">
        <h2>Dashboard Overview</h2>
        <p>Quick stats and charts (placeholder)</p>
        <div className="cards">
          <div className="card">Total Kiosks: --</div>
          <div className="card">Agents: --</div>
          <div className="card">Pending Tasks: --</div>
        </div>
      </div>
    );
  }