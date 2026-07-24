const { test, expect } = require('@playwright/test')
const { login, API_URL } = require('./helpers')

// Scénario critique #12 : seul module sans aucune couverture avant ce plan de
// tests. Piloté via l'API (pas d'UI recrutement dans le frontend aujourd'hui).
test('soumission d\'une candidature puis consultation dans la liste', async ({ request }) => {
  const token = await login(request)
  const email = `candidat.e2e.${Date.now()}@example.com`

  const createRes = await request.post(`${API_URL}/recrutement/candidat`, {
    headers: { Authorization: `Bearer ${token}` },
    multipart: {
      nom: 'Test',
      prenom: 'E2E',
      email,
      poste: 'QA Engineer',
      cv: { name: 'cv.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.4 contenu factice') },
    },
  })
  expect(createRes.status()).toBe(200)
  const created = await createRes.json()
  expect(created.email).toBe(email)
  expect(created.cv_path).toBeTruthy()

  const listRes = await request.get(`${API_URL}/recrutement/candidats`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  expect(listRes.status()).toBe(200)
  const candidats = await listRes.json()
  expect(candidats.some(c => c.email === email)).toBe(true)
})
