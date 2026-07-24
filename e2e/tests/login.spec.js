const { test, expect } = require('@playwright/test')
const { DEMO_USER } = require('./helpers')

// Scénario critique #9 (docs/PLAN-DE-TESTS.md) : c'est ce parcours qu'a cassé
// en prod le bug pathRewrite manquant (404 sur toute route proxyée depuis 2021,
// trouvé et corrigé en Phase 2 du plan de remédiation).
test('connexion réussie affiche le dashboard avec le solde de congés', async ({ page }) => {
  await page.goto('/')
  await page.getByPlaceholder('Email').fill(DEMO_USER.email)
  await page.getByPlaceholder('Mot de passe').fill(DEMO_USER.password)
  await page.getByRole('button', { name: 'Connexion' }).click()

  await expect(page).toHaveURL(/\/dashboard$/)
  await expect(page.getByText(`Bonjour ${DEMO_USER.email}`)).toBeVisible()
  await expect(page.getByText(/Solde congés : \d+ jours/)).toBeVisible()
})

// Scénario critique #10 : évite un dashboard vide/cassé silencieux (symptôme
// du bug d'URL relative de Dashboard.jsx trouvé en testant l'app pour de vrai).
test('connexion échouée affiche un message d\'erreur et ne redirige pas', async ({ page }) => {
  await page.goto('/')
  await page.getByPlaceholder('Email').fill(DEMO_USER.email)
  await page.getByPlaceholder('Mot de passe').fill('mauvais-mot-de-passe')
  await page.getByRole('button', { name: 'Connexion' }).click()

  await expect(page.getByText('Identifiants invalides')).toBeVisible()
  await expect(page).toHaveURL('/')
})
