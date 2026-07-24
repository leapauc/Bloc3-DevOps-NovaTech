process.env.JWT_SECRET = 'test-secret'

const jwt = require('jsonwebtoken')
const requireAuth = require('../auth')

function makeRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn() }
}

describe('requireAuth (middleware gateway)', () => {
  test('401 si aucun header Authorization', () => {
    const req = { headers: {} }
    const res = makeRes()
    const next = jest.fn()
    requireAuth(req, res, next)
    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })

  test('401 si le token est invalide', () => {
    const req = { headers: { authorization: 'Bearer garbage' } }
    const res = makeRes()
    const next = jest.fn()
    requireAuth(req, res, next)
    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })

  test('appelle next() et attache req.user pour un token valide', () => {
    const token = jwt.sign({ userId: 1, role: 'user' }, process.env.JWT_SECRET)
    const req = { headers: { authorization: `Bearer ${token}` } }
    const res = makeRes()
    const next = jest.fn()
    requireAuth(req, res, next)
    expect(next).toHaveBeenCalled()
    expect(req.user.userId).toBe(1)
  })
})
