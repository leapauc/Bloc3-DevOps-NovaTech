import React from 'react' 
import { BrowserRouter, Routes, Route } from 'react-router-dom' 
import Login from './components/Login' 
import Dashboard from './pages/Dashboard' 

/**/
export default function App() { 
  return ( 
    <BrowserRouter> 
      <Routes> 
        <Route path="/" element={<Login />} /> 
        <Route path="/dashboard" element={<Dashboard />} /> 
      </Routes> 
    </BrowserRouter> 
  ) 
} 