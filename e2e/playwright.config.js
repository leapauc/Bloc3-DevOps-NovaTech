// Suite E2E — tourne contre la stack réelle lancée par `docker-compose.yml`
// à la racine du repo (frontend:3005, gateway:3000, Postgres initialisé avec
// docker/init-db.sql). Voir docs/PLAN-DE-TESTS.md pour la justification des
// scénarios et docs/RUNBOOK.md pour comment lancer la stack manuellement.
const { defineConfig, devices } = require('@playwright/test')

module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: false,
  retries: 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: process.env.E2E_FRONTEND_URL || 'http://localhost:3005',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
})
