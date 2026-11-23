const developmentApiUrl = 'http://localhost:3000'
const productionApiUrl = 'https://route-board.azurewebsites.net'

export const apiBase = (
  import.meta.env.VITE_API_BASE_URL ||
  (import.meta.env.DEV ? developmentApiUrl : productionApiUrl)
).replace(/\/+$/, '')