const { test, expect } = require('@playwright/test')
const { DEMO_USER } = require('./helpers')

// Scénario critique #9
// Connexion réussie → redirection vers le dashboard → solde de congés visible.
test('connexion réussie affiche le dashboard avec le solde de congés', async ({ page }) => {
  await page.goto('/')

  await page.getByPlaceholder('Email').fill(DEMO_USER.email)
  await page.getByPlaceholder('Mot de passe').fill(DEMO_USER.password)

  await page.getByRole('button', { name: 'Connexion' }).click()

  // Vérifie la redirection
  await expect(page).toHaveURL(/\/dashboard$/)

  // Vérifie que le dashboard est bien affiché
  await expect(
    page.getByText(`Bonjour,`).first()
  ).toBeVisible()

  await expect(
    page.getByText(DEMO_USER.email, { exact: true })
  ).toBeVisible()

  // Vérifie que le solde de congés est présent
  await expect(
    page.getByText(/Solde congés/i)
  ).toBeVisible()

  await expect(
    page.getByText(/\d+\s*jours/)
  ).toBeVisible()
})


// Scénario critique #10
// Identifiants incorrects → message d'erreur → aucune redirection.
test('connexion échouée affiche un message d\'erreur et ne redirige pas', async ({ page }) => {
  await page.goto('/')

  await page.getByPlaceholder('Email').fill(DEMO_USER.email)
  await page.getByPlaceholder('Mot de passe').fill('mauvais-mot-de-passe')

  await page.getByRole('button', { name: 'Connexion' }).click()

  await expect(
    page.getByText('Identifiants invalides')
  ).toBeVisible()

  await expect(page).toHaveURL(/\/$/)
})