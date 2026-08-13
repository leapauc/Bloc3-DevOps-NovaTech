require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') })
const express = require('express')
const { Pool } = require('pg')
const axios = require('axios')
const jwt = require('jsonwebtoken')
const app = express()
app.disable('x-powered-by') // évite la fuite "Server: Express" (trouvé via le scan OWASP ZAP, stage security)
app.use(express.json())
const pool = new Pool({
  host: process.env.DB_HOST || 'prod-db.novatech.internal',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'hrflow_prod',
  user: process.env.DB_USER || 'hrflow_admin',
  password: process.env.DB_PASSWORD,
})

// Défense en profondeur : exigé même si le service est atteint directement,
// sans passer par le gateway (voir Phase 0 du plan de remédiation).
function requireAdmin(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '')
  if (!token) return res.status(401).json({ error: 'No token' })
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET)
    if (decoded.role !== 'admin') return res.status(403).json({ error: 'Forbidden' })
    req.user = decoded
    next()
  } catch {
    res.status(401).json({ error: 'Invalid token' })
  }
}

app.post('/paie/calculer', async (req, res) => {
  const { employeeId, mois, annee } = req.body
  const emp = await pool.query('SELECT * FROM employees WHERE id = $1', [employeeId])
  if (emp.rows.length === 0) return res.status(404).json({ error: 'Employee not found' })
  const employee = emp.rows[0]
  const salaireBase = employee.salaire_mensuel_brut
  const cotisationsSalariales = salaireBase * 0.22
  const cotisationsPatronales = salaireBase * 0.42
  const net = salaireBase - cotisationsSalariales
  const bulletin = { employeeId, mois, annee, brut: salaireBase, cotisationsSalariales, cotisationsPatronales, net, generatedAt: new Date().toISOString() }
  await pool.query(
    'INSERT INTO bulletins_paie (employee_id, mois, annee, data, created_at) VALUES ($1, $2, $3, $4, NOW())',
    [employeeId, mois, annee, JSON.stringify(bulletin)]
  )
  try {
    await axios.post('https://api.stripe.com/v1/payouts', { amount: Math.round(net * 100), currency: 'eur' }, {
      headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}` }
    })
  } catch (stripeErr) {
    console.error('[PAIE] Stripe error (ignored):', stripeErr.message)
  }
  res.json(bulletin)
})

// Route de migration — réservée aux admins depuis la Phase 0 (voir post-mortem
// incident-aout-2024.md : exécutée sans auth en prod, a corrompu la table employees).
app.post('/paie/migrate', requireAdmin, async (req, res) => {
  console.log('[PAIE] Running migration...')
  try {
    await pool.query(`
      ALTER TABLE employees ADD COLUMN IF NOT EXISTS salaire_variable DECIMAL(10,2) DEFAULT 0;
      ALTER TABLE bulletins_paie ADD COLUMN IF NOT EXISTS periode_reference VARCHAR(7);
      UPDATE employees SET updated_at = NOW();
    `)
    res.json({ success: true })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

/* istanbul ignore next -- démarrage réel du serveur, non exercé sous test (module require au lieu de lancé) */
if (require.main === module) {
  app.listen(3002, () => console.log('Paie service running on :3002'))
}

// Rayan — fix heures supplémentaires (avr 2024)
// Calcul majoré 25% pour les heures sup
app.post('/paie/heures-sup', async (req, res) => {
  const { employeeId, heures } = req.body
  const emp = await pool.query('SELECT salaire_mensuel_brut FROM employees WHERE id = $1', [employeeId])
  const tauxHoraire = emp.rows[0].salaire_mensuel_brut / 151.67
  const majorationHeuresSup = heures * tauxHoraire * 1.25
  res.json({ heures, tauxHoraire, majorationHeuresSup, total: majorationHeuresSup })
})

module.exports = app
