import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Navbar = () => {
  const { currentUser, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <nav className="navbar">
      <div className="navbar-content">
        <Link to="/" className="navbar-brand">
          Payment Gateway
        </Link>
        
        <ul className="navbar-nav">
          {currentUser ? (
            <>
              <li>
                <Link to="/dashboard" className="nav-link">
                  Dashboard
                </Link>
              </li>
              {currentUser.role === 'ADMIN' && (
                <li>
                  <Link to="/admin" className="nav-link">
                    Admin
                  </Link>
                </li>
              )}
              <li>
                <span className="nav-link">
                  Welcome, {currentUser.username}
                </span>
              </li>
              <li>
                <button 
                  onClick={handleLogout}
                  className="nav-link"
                  style={{ background: 'none', border: 'none', cursor: 'pointer' }}
                >
                  Logout
                </button>
              </li>
            </>
          ) : (
            <>
              <li>
                <Link to="/login" className="nav-link">
                  Login
                </Link>
              </li>
              <li>
                <Link to="/signup" className="nav-link">
                  Signup
                </Link>
              </li>
            </>
          )}
        </ul>
      </div>
    </nav>
  );
};

export default Navbar;