const DEMO_USER = {
  email: 'test@novatech.fr',
  password: 'motdepasse123',
  employeeId: 1,
}

const API_URL =
  process.env.E2E_API_URL || 'http://localhost:3006/api'

async function login(request) {
  const url = `${API_URL}/auth/login`

  const res = await request.post(url, {
    data: {
      email: DEMO_USER.email,
      password: DEMO_USER.password,
    },
  })

  const body = await res.json()

  console.log('[E2E AUTH]', {
    url,
    status: res.status(),
    body,
  })

  if (res.status() !== 200) {
    throw new Error(
      `Login E2E échoué: HTTP ${res.status()} - ${JSON.stringify(body)}`
    )
  }

  if (!body.token) {
    throw new Error(
      `Login E2E: aucun token retourné - ${JSON.stringify(body)}`
    )
  }

  return body.token
}

module.exports = {
  DEMO_USER,
  API_URL,
  login,
}