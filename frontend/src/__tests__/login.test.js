import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import axios from 'axios'
import Login from '../components/Login'

jest.mock('axios')

beforeEach(() => {
  localStorage.clear()
  jest.clearAllMocks()
})

describe('Login', () => {
  test('affiche le formulaire de connexion', () => {
    render(<Login />)
    expect(screen.getByPlaceholderText('Email')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('Mot de passe')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Connexion' })).toBeInTheDocument()
  })

  test('affiche une erreur sur identifiants invalides', async () => {
    axios.post.mockRejectedValueOnce({ response: { data: { error: 'Invalid credentials' } } })
    render(<Login />)
    fireEvent.change(screen.getByPlaceholderText('Email'), { target: { value: 'a@b.com' } })
    fireEvent.change(screen.getByPlaceholderText('Mot de passe'), { target: { value: 'wrong' } })
    fireEvent.click(screen.getByRole('button', { name: 'Connexion' }))
    expect(await screen.findByText('Identifiants invalides')).toBeInTheDocument()
  })

  test('stocke le token et l\'utilisateur en cas de succès', async () => {
    axios.post.mockResolvedValueOnce({ data: { token: 'abc', user: { id: 1, email: 'a@b.com', role: 'user' } } })
    render(<Login />)
    fireEvent.change(screen.getByPlaceholderText('Email'), { target: { value: 'a@b.com' } })
    fireEvent.change(screen.getByPlaceholderText('Mot de passe'), { target: { value: 'good' } })
    fireEvent.click(screen.getByRole('button', { name: 'Connexion' }))
    await waitFor(() => expect(localStorage.getItem('hrflow_token')).toBe('abc'))
    expect(JSON.parse(localStorage.getItem('hrflow_user'))).toEqual({ id: 1, email: 'a@b.com', role: 'user' })
  })
})
