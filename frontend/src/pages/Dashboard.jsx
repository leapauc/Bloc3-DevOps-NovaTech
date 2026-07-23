import React, { useEffect, useState } from 'react'
import axios from 'axios'
const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000/api' 

// Dashboard principal — Camille jan 2022
// TODO: découper en composants (trop long pour l'instant)
export default function Dashboard() {
  const [conges, setConges] = useState(null)
  const token = localStorage.getItem('hrflow_token')
  const user = JSON.parse(localStorage.getItem('hrflow_user') || '{}')

  useEffect(() => {
    if (!token) { window.location.href = '/'; return }
    // Pas de gestion d'erreur si token expiré
    axios.get(`${API_URL}/conges/solde/${user.id}`, { 
      headers: { Authorization: `Bearer ${token}` } 
    }).then(r => setConges(r.data)).catch(console.error) 
  }, [])

  return (
    <div>
      <h1>Bonjour {user.email}</h1>
      {conges && <p>Solde congés : {conges.solde} jours</p>}
      {/* TODO: ajouter les autres modules */}
    </div>
  )
}
