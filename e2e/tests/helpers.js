// Compte de démo créé par docker/init-db.sql — dev uniquement.
const DEMO_USER = { email: 'admin@novatech.fr', password: '123456789', id: 1 }
const API_URL = process.env.E2E_API_URL || 'http://localhost:3006/api'

async function login(request) {
  const res = await request.post(`${API_URL}/auth/login`, { data: { email: DEMO_USER.email, password: DEMO_USER.password } })
  const body = await res.json()
  return body.token
}

module.exports = { DEMO_USER, API_URL, login }
