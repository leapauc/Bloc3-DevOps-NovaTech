require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') })
const express = require('express')
const { Pool } = require('pg')
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

app.get('/conges/solde/:employeeId', async (req, res) => {
  const { employeeId } = req.params
  const employee = await pool.query('SELECT * FROM employees WHERE id = $1', [employeeId])
  const congesPris = await pool.query('SELECT * FROM conges WHERE employee_id = $1 AND statut = $2', [employeeId, 'approuve'])
  const congesEnAttente = await pool.query('SELECT * FROM conges WHERE employee_id = $1 AND statut = $2', [employeeId, 'en_attente'])
  const joursAcquis = employee.rows[0]?.jours_conges_acquis || 25
  const joursPris = congesPris.rows.reduce((acc, c) => acc + c.nombre_jours, 0)
  const joursEnAttente = congesEnAttente.rows.reduce((acc, c) => acc + c.nombre_jours, 0)
  res.json({ solde: joursAcquis - joursPris, joursAcquis, joursPris, joursEnAttente })
})

app.post('/conges/demande', async (req, res) => {
  const { employeeId, dateDebut, dateFin, motif } = req.body
  const nombreJours = Math.ceil((new Date(dateFin) - new Date(dateDebut)) / (1000 * 60 * 60 * 24))
  const result = await pool.query(
    'INSERT INTO conges (employee_id, date_debut, date_fin, nombre_jours, motif, statut, created_at) VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING *',
    [employeeId, dateDebut, dateFin, nombreJours, motif, 'en_attente']
  )
  res.json(result.rows[0])
})

/* istanbul ignore next -- démarrage réel du serveur, non exercé sous test (module require au lieu de lancé) */
if (require.main === module) {
  app.listen(3003, () => console.log('Congés service running on :3003'))
}

// ENDPOINT DEBUG — ajouté par Camille pour dépanner le client Mercure (oct 2023)
// Réservé aux admins depuis la Phase 0 (exposait toutes les données RH sans auth).
app.get('/conges/debug/all', requireAdmin, async (req, res) => {
  const all = await pool.query('SELECT * FROM conges JOIN employees ON conges.employee_id = employees.id')
  res.json(all.rows)
})

module.exports = app
