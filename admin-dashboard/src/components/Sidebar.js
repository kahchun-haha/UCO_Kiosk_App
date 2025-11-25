import React from 'react';
import { NavLink } from 'react-router-dom';

export default function Sidebar({ role, onLogout }) {
  
  const NavItem = ({ to, icon, label }) => (
    <NavLink 
      to={to} 
      className={({ isActive }) => 
        `flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 mb-1 ${
          isActive 
            ? "bg-primary text-white shadow-md shadow-primary/30 font-semibold" 
            : "text-gray-400 hover:bg-white/5 hover:text-white"
        }`
      }
    >
      <span className="text-xl">{icon}</span>
      <span className="text-sm font-medium">{label}</span>
    </NavLink>
  );

  return (
    // CHANGED: Removed 'bg-gradient-to-b from-dark to-dark-light'
    // ADDED: 'bg-dark' (Solid Color) and 'border-r border-white/5' for subtle definition
    <aside className="w-72 bg-dark text-white min-h-screen p-6 flex flex-col shadow-xl z-10 border-r border-white/5">
      
      {/* Header */}
      <div className="mb-10 px-2">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center text-2xl text-primary">
            ♻️
          </div>
          <span className="text-xl font-bold tracking-wide text-white">UMinyak</span>
        </div>
        <p className="text-xs text-gray-500 uppercase tracking-wider font-bold ml-1">
          {role === 'superadmin' ? 'Super Admin Console' : 'Admin Dashboard'}
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 flex flex-col">
        <NavItem to="/" icon="📊" label="Dashboard" />
        <NavItem to="/users" icon="👥" label="Users" />
        <NavItem to="/kiosks" icon="📍" label="Kiosks" />
        <NavItem to="/tasks" icon="📋" label="Tasks" />
        
        {(role === 'admin' || role === 'superadmin') && (
          <>
            <div className="my-6 border-t border-white/5 mx-2"></div>
            <p className="px-4 text-xs text-gray-500 font-bold mb-3 uppercase">Management</p>
            <NavItem to="/agents" icon="🛡️" label="Agents" />
          </>
        )}
        
        {role === 'superadmin' && (
          <NavItem to="/admins" icon="🔑" label="Admins" />
        )}
      </nav>

      {/* Logout */}
      <div className="mt-auto pt-6 border-t border-white/5">
        <button 
          onClick={onLogout} 
          className="w-full flex items-center justify-center gap-2 text-red-400 hover:bg-red-500/10 hover:text-red-300 px-4 py-3 rounded-xl transition-all duration-200"
        >
          <span>🚪</span>
          <span className="font-medium">Sign Out</span>
        </button>
      </div>
    </aside>
  );
}