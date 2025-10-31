import React, { createContext, useState, useContext, useEffect } from 'react';
import axios from 'axios';

const AuthContext = createContext();

export const useAuth = () => {
  return useContext(AuthContext);
};

export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      const userData = JSON.parse(localStorage.getItem('userData'));
      setCurrentUser(userData);
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }
    setLoading(false);
  }, []);

  const login = async (username, password) => {
    try {
      const response = await axios.post('/api/auth/login', {
        username,
        password
      });

      if (response.data.success) {
        const { token, ...userData } = response.data.data;
        localStorage.setItem('token', token);
        localStorage.setItem('userData', JSON.stringify(userData));
        axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
        setCurrentUser(userData);
        return { success: true };
      }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Login failed' 
      };
    }
  };

  const signup = async (username, email, password, role = 'MERCHANT') => {
    try {
      const response = await axios.post('/api/auth/signup', {
        username,
        email,
        password,
        role
      });

      if (response.data.success) {
        const { token, ...userData } = response.data.data;
        localStorage.setItem('token', token);
        localStorage.setItem('userData', JSON.stringify(userData));
        axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
        setCurrentUser(userData);
        return { success: true };
      }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Signup failed' 
      };
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('userData');
    delete axios.defaults.headers.common['Authorization'];
    setCurrentUser(null);
  };

  const value = {
    currentUser,
    login,
    signup,
    logout
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
};