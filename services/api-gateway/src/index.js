require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') })
const express = require('express')
const { createProxyMiddleware } = require('http-proxy-middleware')
const requireAuth = require('./middleware/auth')
const app = express()
app.disable('x-powered-by') // évite la fuite "Server: Express" (trouvé via le scan OWASP ZAP, stage security)

const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || 'https://hrflow.novatech.io,https://staging.hrflow.novatech.io')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean)

app.use((req, res, next) => {
  const origin = req.headers.origin
  if (origin && allowedOrigins.includes(origin)) {
    res.header('Access-Control-Allow-Origin', origin)
    res.header('Vary', 'Origin')
  }
  res.header('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS')
  res.header('Access-Control-Allow-Headers', 'Content-Type,Authorization')
  if (req.method === 'OPTIONS') return res.sendStatus(204)
  next()
})


const stripApiPrefix = { pathRewrite: { '^/api': '' } }

const AUTH_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:3001'
const PAIE_URL = process.env.PAIE_SERVICE_URL || 'http://localhost:3002'
const CONGES_URL = process.env.CONGES_SERVICE_URL || 'http://localhost:3003'
const RECRUTEMENT_URL = process.env.RECRUTEMENT_SERVICE_URL || 'http://localhost:3004'

app.use('/api/auth', createProxyMiddleware({ target: AUTH_URL, changeOrigin: true, ...stripApiPrefix }))
app.use('/api/paie', requireAuth, createProxyMiddleware({ target: PAIE_URL, changeOrigin: true, ...stripApiPrefix }))
app.use('/api/conges', requireAuth, createProxyMiddleware({ target: CONGES_URL, changeOrigin: true, ...stripApiPrefix }))
app.use('/api/recrutement', requireAuth, createProxyMiddleware({ target: RECRUTEMENT_URL, changeOrigin: true, ...stripApiPrefix }))

app.get('/health', (req, res) => res.json({ status: 'ok' }))

app.use((err, req, res, next) => {
  console.error(err.stack)
  res.status(500).json({ error: err.message, stack: err.stack })
})

/* istanbul ignore next */
if (require.main === module) {
  app.listen(3000, () => {
    console.log('API Gateway running on :3000')
  })
}

module.exports = app
