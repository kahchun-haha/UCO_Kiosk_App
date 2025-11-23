import React from 'react';
import { NavLink } from 'react-router-dom';

export default function Sidebar({ role, onLogout }){
  return (
    <aside className="w-64 bg-slate-800 text-white min-h-screen p-6">
      <div className="mb-8">
        <div className="text-3xl">🛢️</div>
        <h1 className="text-xl font-semibold">UMinyak Admin</h1>
        <p className="text-sm text-slate-300">Admin Panel</p>
      </div>

      <nav className="flex flex-col gap-2">
        <NavLink to="/" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Dashboard</NavLink>
        <NavLink to="/kiosks" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Kiosks</NavLink>
        <NavLink to="/tasks" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Tasks</NavLink>
        <NavLink to="/users" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Users (View)</NavLink>
        {(role === 'admin' || role === 'superadmin') && <NavLink to="/agents" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Agents</NavLink>}
        {role === 'superadmin' && <NavLink to="/admins" className={({isActive}) => "px-3 py-2 rounded " + (isActive ? "bg-sky-600" : "hover:bg-slate-700")}>Admins</NavLink>}
      </nav>

      <div className="mt-8">
        <button onClick={onLogout} className="w-full bg-red-600 px-3 py-2 rounded">Logout</button>
      </div>
    </aside>
  );
}
