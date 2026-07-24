const { test, expect } = require('@playwright/test')

// Scénario critique #11 : pas de donnée exposée côté client sans authentification.
test('accès direct à /dashboard sans session redirige vers le login', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page).toHaveURL('/')
})
