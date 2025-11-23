import React from 'react';
import { NavLink } from 'react-router-dom';

export default function Sidebar({ role, onLogout }) {
  
  const NavItem = ({ to, icon, label }) => (
    <NavLink 
      to={to} 
      className={({ isActive }) => 
        `flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 ${
          isActive 
            ? "bg-primary text-white shadow-md shadow-primary/30 font-semibold" 
            : "text-gray-300 hover:bg-white/10 hover:text-white"
        }`
      }
    >
      <span className="text-xl">{icon}</span>
      <span className="text-sm">{label}</span>
    </NavLink>
  );

  return (
    <aside className="w-72 bg-gradient-to-b from-dark to-dark-light text-white min-h-screen p-6 flex flex-col shadow-xl z-10">
      {/* UPDATED HEADER */}
      <div className="mb-10 px-2">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 bg-white/10 rounded-full flex items-center justify-center text-2xl">
            ♻️
          </div>
          <h1 className="text-xl font-bold tracking-wide">UMinyak</h1>
        </div>
        <p className="text-xs text-gray-400 uppercase tracking-wider font-semibold ml-1">
          {role === 'superadmin' ? 'Super Admin Console' : 'Admin Dashboard'}
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 flex flex-col gap-2">
        <NavItem to="/" icon="📊" label="Dashboard" />
        <NavItem to="/users" icon="👥" label="Users" />
        <NavItem to="/kiosks" icon="📍" label="Kiosks" />
        <NavItem to="/tasks" icon="📋" label="Tasks" />
        
        {(role === 'admin' || role === 'superadmin') && (
          <>
            <div className="my-4 border-t border-white/10 mx-2"></div>
            <p className="px-4 text-xs text-gray-500 font-semibold mb-2 uppercase">Management</p>
            <NavItem to="/agents" icon="🛡️" label="Agents" />
          </>
        )}
        
        {role === 'superadmin' && (
          <NavItem to="/admins" icon="🔑" label="Admins" />
        )}
      </nav>

      {/* Logout */}
      <div className="mt-auto pt-6">
        <button 
          onClick={onLogout} 
          className="w-full flex items-center justify-center gap-2 bg-red-500/10 text-red-400 hover:bg-red-500 hover:text-white px-4 py-3 rounded-xl transition-all duration-200"
        >
          <span>🚪</span>
          <span className="font-medium">Sign Out</span>
        </button>
      </div>
    </aside>
  );
}