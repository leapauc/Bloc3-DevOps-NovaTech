const { test, expect } = require('@playwright/test')
const { login, API_URL, DEMO_USER } = require('./helpers')

// Scénario critique #13 : traverse gateway → service → Postgres réel, valide
// le calcul de dates de bout en bout (pas juste mocké comme en test unitaire).
test('une demande de congé authentifiée calcule le bon nombre de jours', async ({ request }) => {
  const token = await login(request)

  const res = await request.post(`${API_URL}/conges/demande`, {
    headers: { Authorization: `Bearer ${token}` },
    data: {
      employeeId: DEMO_USER.employeeId,
      dateDebut: '2026-09-01',
      dateFin: '2026-09-05',
      motif: 'Test E2E',
    },
  })
  expect(res.status()).toBe(200)
  const demande = await res.json()
  expect(demande.nombre_jours).toBe(4)
  expect(demande.statut).toBe('en_attente')
})

test('sans token, la demande de congé est rejetée (401) via le gateway', async ({ request }) => {
  const res = await request.post(`${API_URL}/conges/demande`, {
    data: { employeeId: DEMO_USER.employeeId, dateDebut: '2026-09-01', dateFin: '2026-09-05' },
  })
  expect(res.status()).toBe(401)
})
