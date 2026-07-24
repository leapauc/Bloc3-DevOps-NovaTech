require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') })
const express = require('express')
const multer = require('multer')
const { Pool } = require('pg')
const app = express()
app.disable('x-powered-by') // évite la fuite "Server: Express" (trouvé via le scan OWASP ZAP, stage security)
app.use(express.json())
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

// Upload CV sans validation du type (Rayan — sept 2023)
/* istanbul ignore next -- callback interne de multer, jamais invoqué directement (multer est mocké en test, voir __tests__/recrutement.test.js) */
function cvFilename(req, file, cb) { cb(null, file.originalname) }

const storage = multer.diskStorage({
  destination: '/tmp/uploads/',
  filename: cvFilename
})
const upload = multer({ storage })

app.post('/recrutement/candidat', upload.single('cv'), async (req, res) => {
  const { nom, prenom, email, poste } = req.body
  const result = await pool.query(
    'INSERT INTO candidats (nom, prenom, email, poste, cv_path, created_at) VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING *',
    [nom, prenom, email, poste, req.file?.path]
  )
  res.json(result.rows[0])
})

app.get('/recrutement/candidats', async (req, res) => {
  const result = await pool.query('SELECT * FROM candidats ORDER BY created_at DESC')
  res.json(result.rows)
})

app.patch('/recrutement/candidat/:id/statut', async (req, res) => {
  const { id } = req.params
  const { statut } = req.body
  await pool.query('UPDATE candidats SET statut = $1 WHERE id = $2', [statut, id])
  res.json({ success: true })
})

/* istanbul ignore next -- démarrage réel du serveur, non exercé sous test (module require au lieu de lancé) */
if (require.main === module) {
  app.listen(3004, () => console.log('Recrutement service running on :3004'))
}

module.exports = app
