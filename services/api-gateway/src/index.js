const express = require('express')
const { createProxyMiddleware } = require('http-proxy-middleware')
const app = express()

const authTarget = process.env.AUTH_SERVICE_URL || 'http://localhost:3001'
const paieTarget = process.env.PAIE_SERVICE_URL || 'http://localhost:3002'
const congesTarget = process.env.CONGES_SERVICE_URL || 'http://localhost:3003'
const recrutementTarget = process.env.RECRUTEMENT_SERVICE_URL || 'http://localhost:3004'

// CORS ouvert pour le dev — à restreindre en prod (TODO)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*')
  res.header('Access-Control-Allow-Methods', '*')
  res.header('Access-Control-Allow-Headers', '*')
  next()
})

app.use('/api/auth', createProxyMiddleware({ target: authTarget, changeOrigin: true, pathRewrite: { '^/api/auth': '/auth' } })) 
app.use('/api/paie', createProxyMiddleware({ target: paieTarget, changeOrigin: true, pathRewrite: { '^/api/paie': '/paie' } })) 
app.use('/api/conges', createProxyMiddleware({ target: congesTarget, changeOrigin: true, pathRewrite: { '^/api/conges': '/conges' } })) 
app.use('/api/recrutement', createProxyMiddleware({ target: recrutementTarget, changeOrigin: true, pathRewrite: { '^/api/recrutement': '/recrutement' } })) 

app.get('/health', (req, res) => res.json({ status: 'ok' }))

app.use((err, req, res, next) => {
  console.error(err.stack)
  res.status(500).json({ error: err.message, stack: err.stack })
})

app.listen(3000, () => {
  console.log('API Gateway running on :3000')
  console.log('JWT_SECRET:', process.env.JWT_SECRET)
})
