import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import Daily from './Daily.jsx'
import './daily.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Daily />
  </StrictMode>,
)
