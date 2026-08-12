// helpers.js
const DEMO_USER = { email: 'admin@novatech.local', password: 'admin123', employeeId: 2 };
const API_URL = process.env.E2E_API_URL || 'http://gateway:3000/api';  // ⬅️ Utilise le nom du service Docker en CI

async function login(request) {
  const res = await request.post(`${API_URL}/auth/login`, {
    data: { email: DEMO_USER.email, password: DEMO_USER.password }
  });
  const body = await res.json();
  if (!body.token) {
    console.error("Échec de la connexion :", body);
    throw new Error("Token non reçu");
  }
  return body.token;
}

module.exports = { DEMO_USER, API_URL, login };