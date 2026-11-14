import { useEffect, useRef, useState, type FormEvent } from 'react'
import { createFileRoute, Link } from '@tanstack/react-router'

export const Route = createFileRoute('/dispatch')({ component: DispatchPage })

type TripStatus = 'Scheduled' | 'In progress' | 'Delayed' | 'Canceled' | 'Completed'
type EventKind = 'Created' | 'Departure' | 'Stop arrival' | 'Vehicle assignment' | 'Status'

type Trip = {
  id: string
  route: string
  destination: string
  vehicle: string
  stops: string[]
  nextStopIndex: number
  departed: boolean
  status: TripStatus
}

type Activity = {
  id: number
  time: string
  message: string
  kind: EventKind
}

type Dispatcher = {
  email: string
  name?: string
  image?: string
}

type ApiTrip = {
  id: string
  route: string
  destination: string
  vehicle: string
  stops: string[]
  nextStopIndex: number
  departed: boolean
  status: TripStatus
}

class ApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message)
  }
}

const apiBase = (import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000').replace(/\/$/, '')

async function apiRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${apiBase}${path}`, {
    ...init,
    credentials: 'include',
    headers: { ...(init.body ? { 'Content-Type': 'application/json' } : {}), ...init.headers },
  })
  const payload = response.status === 204 ? null : await response.json().catch(() => null)
  if (!response.ok) throw new ApiError(response.status, payload?.error ?? 'The request could not be completed.')
  return payload as T
}

function tripFromApi(trip: ApiTrip): Trip {
  return { ...trip }
}

const vehicles = ['Shuttle 204', 'Shuttle 318', 'Shuttle 409', 'Shuttle 512']

function timestamp() {
  return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

function DispatchPage() {
  const [trips, setTrips] = useState<Trip[]>([])
  const [dispatcher, setDispatcher] = useState<Dispatcher | null>(null)
  const [authLoading, setAuthLoading] = useState(true)
  const [tripsLoading, setTripsLoading] = useState(true)
  const authPopup = useRef<Window | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [activities, setActivities] = useState<Activity[]>([])
  const [routeName, setRouteName] = useState('')
  const [destination, setDestination] = useState('')
  const [stopsText, setStopsText] = useState('')
  const [newVehicle, setNewVehicle] = useState(vehicles[0])

  useEffect(() => {
    let active = true
    const authError = new URLSearchParams(window.location.search).get('auth_error')
    if (authError) setErrorMessage(authError === 'unauthorized' ? 'Access denied: unauthorized account' : 'Google sign-in failed. Please try again.')

    async function loadAuthorizedWorkspace() {
      setAuthLoading(true)
      try {
        const identity = await apiRequest<Dispatcher>('/api/v1/dispatcher/me')
        if (!active) return
        setDispatcher(identity)
        const response = await apiRequest<ApiTrip[]>('/api/v1/dispatcher/trips')
        if (active) {
          setTrips(response.map(tripFromApi))
          setErrorMessage('')
        }
      } catch (error) {
        if (!active) return
        if (error instanceof ApiError && error.status === 401) {
          setDispatcher(null)
          return
        }
        if (error instanceof ApiError && error.status === 403) {
          setDispatcher(null)
          setErrorMessage('Access denied: unauthorized account')
        } else {
          setErrorMessage(error instanceof Error ? error.message : 'Unable to load the dispatch workspace.')
        }
      } finally {
        if (active) {
          setAuthLoading(false)
          setTripsLoading(false)
        }
      }
    }

    function onAuthPopupMessage(event: MessageEvent<{ type?: string; status?: string }>) {
      if (event.origin !== new URL(apiBase).origin || event.source !== authPopup.current || event.data?.type !== 'routeboard-auth') return
      authPopup.current = null
      if (event.data.status === 'success') {
        setErrorMessage('')
        void loadAuthorizedWorkspace()
      } else {
        setDispatcher(null)
        setAuthLoading(false)
        setErrorMessage(event.data.status === 'unauthorized' ? 'Access denied: unauthorized account' : 'Google sign-in failed. Please try again.')
      }
    }

    window.addEventListener('message', onAuthPopupMessage)
    void loadAuthorizedWorkspace()

    return () => {
      active = false
      window.removeEventListener('message', onAuthPopupMessage)
    }
  }, [])

  function handleApiError(error: unknown) {
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
      setDispatcher(null)
      setErrorMessage('Access denied: unauthorized account')
    } else {
      setErrorMessage(error instanceof Error ? error.message : 'The dispatch change could not be saved.')
    }
  }

  async function persistTripAction(trip: Trip, actionName: string, extra: Record<string, string> = {}) {
    try {
      const response = await apiRequest<{ trip: ApiTrip }>(`/api/v1/dispatcher/trips/${encodeURIComponent(trip.id)}/stops`, {
        method: 'POST',
        body: JSON.stringify({ action_name: actionName, ...extra }),
      })
      const savedTrip = tripFromApi(response.trip)
      setTrips((current) => current.map((item) => item.id === savedTrip.id ? savedTrip : item))
      setErrorMessage('')
      return true
    } catch (error) {
      handleApiError(error)
      return false
    }
  }

  function logEvent(message: string, kind: EventKind) {
    setActivities((current) => [{ id: Date.now(), time: timestamp(), message, kind }, ...current])
  }

  async function createTrip(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!dispatcher) return
    const route = routeName.trim()
    const finalStop = destination.trim()
    if (!route || !finalStop) return

    const stops = [...new Set([...stopsText.split(',').map((stop) => stop.trim()).filter(Boolean), finalStop])]
    try {
      const response = await apiRequest<{ trip: ApiTrip }>('/api/v1/dispatcher/trips', {
        method: 'POST',
        body: JSON.stringify({ trip: { route_name: route, destination: finalStop, vehicle: newVehicle, stops } }),
      })
      const trip = tripFromApi(response.trip)
      setTrips((current) => [trip, ...current])
      logEvent(`${trip.id} created for ${route} with ${newVehicle}.`, 'Created')
      setErrorMessage('')
    } catch (error) {
      handleApiError(error)
      return
    }
    setRouteName('')
    setDestination('')
    setStopsText('')
  }

  async function assignVehicle(trip: Trip, vehicle: string) {
    if (!dispatcher || !await persistTripAction(trip, 'vehicle', { vehicle })) return
    logEvent(`${trip.id} assigned to ${vehicle}.`, 'Vehicle assignment')
  }

  async function recordDeparture(trip: Trip) {
    if (!dispatcher || !await persistTripAction(trip, 'departure')) return
    logEvent(`${trip.id} departed for ${trip.destination}.`, 'Departure')
  }

  async function recordStopArrival(trip: Trip) {
    if (!dispatcher || !await persistTripAction(trip, 'arrived')) return
    const arrivedStop = trip.stops[trip.nextStopIndex]
    const completed = trip.nextStopIndex + 1 >= trip.stops.length
    logEvent(`${trip.id} arrived at ${arrivedStop}.${completed ? ' Trip completed.' : ''}`, 'Stop arrival')
  }

  async function updateStatus(trip: Trip, status: TripStatus) {
    if (!dispatcher || !await persistTripAction(trip, 'status', { status })) return
    logEvent(`${trip.id} marked ${status.toLowerCase()}.`, 'Status')
  }

  async function signOut() {
    try {
      await apiRequest<null>('/logout', { method: 'DELETE' })
      setDispatcher(null)
      setErrorMessage('')
    } catch (error) {
      handleApiError(error)
    }
  }

  function openSignIn() {
    const popup = window.open(`${apiBase}/auth/google`, 'routeboard-google-signin', 'popup,width=520,height=680,resizable,scrollbars')
    if (!popup) {
      setErrorMessage('Your browser blocked the sign-in popup. Allow popups for this site and try again.')
      return
    }
    authPopup.current = popup
    popup.focus()
  }

  const openTrips = trips.filter((trip) => trip.status !== 'Completed' && trip.status !== 'Canceled').length
  const onRoute = trips.filter((trip) => trip.departed && trip.status !== 'Completed' && trip.status !== 'Canceled').length
  const delayedTrips = trips.filter((trip) => trip.status === 'Delayed').length

  if (!dispatcher) {
    return (
      <main className="grid min-h-screen place-items-center bg-[#f4f7f5] px-5 font-['Work_Sans',sans-serif] text-[#192b35]">
        <section className="w-full max-w-md border border-[#dce4e5] bg-white p-7 text-center shadow-sm">
          <span className="material-symbols-outlined mx-auto mb-4 grid size-12 place-items-center rounded bg-[#126b91] text-2xl text-white">lock</span>
          <p className="mb-2 text-[10px] font-bold uppercase tracking-[.1em] text-[#126b91]">RouteBoard Dispatcher</p>
          <h1 className="m-0 font-['Space_Grotesk',sans-serif] text-2xl font-semibold">{authLoading ? 'Verifying access' : 'Sign in to continue'}</h1>
          <p className="mb-0 mt-3 text-sm leading-relaxed text-[#687780]">The dispatch workspace is available only to the authorized dispatcher account.</p>
          {errorMessage && <p className="mt-4 border border-[#ecd1cf] bg-[#fcebea] px-3 py-2 text-left text-xs text-[#8d302a]" role="alert">{errorMessage}</p>}
          {!authLoading && <button className="mt-5 inline-flex h-10 items-center justify-center gap-2 rounded bg-[#126b91] px-4 text-xs font-semibold text-white hover:bg-[#0e5a7b]" type="button" onClick={openSignIn}><span className="material-symbols-outlined text-base">account_circle</span>Sign in with Google</button>}
        </section>
      </main>
    )
  }

  return (
    <div className="min-h-screen bg-[#f4f7f5] font-['Work_Sans',sans-serif] text-sm text-[#192b35]">
      <header className="sticky top-0 z-10 flex min-h-[68px] items-center justify-between gap-4 border-b border-[#dce4e5] bg-white/95 px-4 py-2.5 md:px-6 xl:px-[max(24px,calc((100vw-1440px)/2))]">
        <Link className="flex items-center gap-2.5 text-inherit no-underline" to="/" aria-label="RouteBoard arrivals">
          <span className="material-symbols-outlined grid size-[42px] place-items-center rounded-lg bg-[#126b91] text-2xl text-white">directions_bus</span>
          <span className="flex flex-col gap-[3px]"><strong className="font-['Space_Grotesk',sans-serif] text-lg font-semibold leading-none">RouteBoard</strong><small className="text-[9px] font-semibold uppercase tracking-wide text-[#687780]">Dispatcher workspace</small></span>
        </Link>
        <nav className="flex items-center gap-2 sm:gap-3" aria-label="Main navigation">
          <Link className="rounded px-3 py-2 text-xs font-semibold text-[#687780] no-underline hover:bg-[#f1f5f3]" to="/">Arrival board</Link>
          <span className="rounded bg-[#e8f2f4] px-3 py-2 text-xs font-semibold text-[#126b91]">Dispatch</span>
          <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-2 text-[10px] font-semibold uppercase ${dispatcher ? 'border-[#b7e2cf] bg-[#e1f4eb] text-[#126a4d]' : 'border-[#ead9b5] bg-[#fff7e8] text-[#86601d]'}`}><i className={`size-[7px] rounded-full ${dispatcher ? 'bg-[#1c9a6d]' : 'bg-[#b57b1e]'}`} />{authLoading ? 'Checking...' : dispatcher ? 'Live mode' : 'Read only'}</span>
          {dispatcher ? <>
            <span className="hidden max-w-[190px] items-center gap-2 text-[11px] font-semibold text-[#52636b] md:inline-flex" title={dispatcher.email}>
              {dispatcher.image ? <img className="size-7 rounded-full object-cover" src={dispatcher.image} alt="" /> : <span className="grid size-7 place-items-center rounded-full bg-[#e7f2f5] text-xs text-[#126b91]">{dispatcher.email.slice(0, 1).toUpperCase()}</span>}
              <span className="truncate">{dispatcher.email}</span>
            </span>
            <button className="rounded border border-[#dce4e5] bg-white px-2.5 py-2 text-[10px] font-semibold text-[#52636b] hover:bg-[#f4f7f5]" type="button" onClick={signOut}>Sign out</button>
          </> : <a className="rounded bg-[#126b91] px-3 py-2 text-[10px] font-semibold text-white no-underline hover:bg-[#0e5a7b]" href={`${apiBase}/auth/google`}>Sign in with Google</a>}
        </nav>
      </header>

      {errorMessage && <div className="mx-auto mt-3 flex w-[calc(100%-28px)] max-w-[1392px] items-center justify-between gap-3 border border-[#ecd1cf] bg-[#fcebea] px-3 py-2 text-xs text-[#8d302a] sm:w-[calc(100%-32px)] lg:w-[calc(100%-48px)]" role="alert"><span>{errorMessage}</span><button className="rounded px-2 py-1 font-semibold text-[#8d302a] hover:bg-white/60" type="button" onClick={() => setErrorMessage('')} aria-label="Dismiss error">Dismiss</button></div>}

      <main className="mx-auto w-[calc(100%-28px)] max-w-[1392px] py-6 sm:w-[calc(100%-32px)] lg:w-[calc(100%-48px)] lg:py-8">
        <section className="mb-6 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
          <div>
            <div className="mb-2 flex items-center gap-2 text-[10px] font-bold uppercase tracking-[.1em] text-[#126b91]"><i className="size-[7px] rounded-full bg-[#1c9a6d]" />Operations / Dispatch</div>
            <h1 className="m-0 font-['Space_Grotesk',sans-serif] text-[28px] leading-tight font-semibold sm:text-[32px]">Trip control</h1>
            <p className="mb-0 mt-2 max-w-[620px] text-sm leading-relaxed text-[#687780]">Create runs, assign vehicles, and keep stop events and service status up to date.</p>
          </div>
          <span className={`inline-flex w-fit items-center gap-1.5 rounded border px-2.5 py-2 text-[10px] font-semibold ${dispatcher ? 'border-[#b7e2cf] bg-[#e1f4eb] text-[#126a4d]' : 'border-[#ead9b5] bg-[#fff7e8] text-[#86601d]'}`}><span className="material-symbols-outlined text-base">{dispatcher ? 'cloud_done' : 'visibility'}</span>{dispatcher ? 'Changes save to Rails' : 'Read-only access'}</span>
        </section>

        <section className="mb-5 grid grid-cols-1 border-y border-[#dce4e5] bg-white sm:grid-cols-3" aria-label="Dispatch summary">
          <div className="flex items-center gap-3 border-b border-[#e5ebea] px-4 py-3 sm:border-r sm:border-b-0"><span className="material-symbols-outlined grid size-9 place-items-center rounded bg-[#e7f2f5] text-[#126b91]">route</span><span><small className="block text-[10px] text-[#687780]">Open trips</small><strong className="font-['Space_Grotesk',sans-serif] text-lg">{openTrips}</strong></span></div>
          <div className="flex items-center gap-3 border-b border-[#e5ebea] px-4 py-3 sm:border-r sm:border-b-0"><span className="material-symbols-outlined grid size-9 place-items-center rounded bg-[#e8f4ed] text-[#087a59]">directions_bus</span><span><small className="block text-[10px] text-[#687780]">On route</small><strong className="font-['Space_Grotesk',sans-serif] text-lg">{onRoute}</strong></span></div>
          <div className="flex items-center gap-3 px-4 py-3"><span className="material-symbols-outlined grid size-9 place-items-center rounded bg-[#fff1e2] text-[#a75a16]">warning</span><span><small className="block text-[10px] text-[#687780]">Delayed</small><strong className="font-['Space_Grotesk',sans-serif] text-lg">{delayedTrips}</strong></span></div>
        </section>

        <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1.8fr)_minmax(300px,.8fr)]">
          <section className="min-w-0" aria-labelledby="trips-heading">
            <div className="mb-3 flex items-center justify-between gap-3"><div><h2 id="trips-heading" className="m-0 font-['Space_Grotesk',sans-serif] text-lg font-semibold">Today's trips</h2><p className="mb-0 mt-1 text-[11px] text-[#687780]">{tripsLoading ? 'Loading live data...' : `${trips.length} runs on the board`}</p></div><span className="text-[10px] font-medium text-[#687780]">{dispatcher ? 'Saved dispatch data' : 'Live data · read only'}</span></div>
            <div className="flex flex-col gap-2">
              {trips.map((trip) => {
                const terminal = trip.status === 'Canceled' || trip.status === 'Completed'
                const nextStop = trip.stops[trip.nextStopIndex]
                return (
                  <article className="min-w-0 border border-[#dce4e5] bg-white p-3 sm:p-4" key={trip.id}>
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="flex min-w-0 items-start gap-3">
                        <span className="material-symbols-outlined grid size-10 shrink-0 place-items-center rounded-md bg-[#126b91] text-white">directions_bus</span>
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-2"><h3 className="m-0 font-['Space_Grotesk',sans-serif] text-sm font-semibold">{trip.route}</h3><span className={`rounded px-2 py-1 text-[9px] font-bold uppercase ${trip.status === 'Delayed' ? 'bg-[#fff1e2] text-[#a75a16]' : trip.status === 'Canceled' ? 'bg-[#fcebea] text-[#a33c36]' : trip.status === 'Completed' ? 'bg-[#e8f4ed] text-[#087a59]' : trip.status === 'In progress' ? 'bg-[#e7f2f5] text-[#126b91]' : 'bg-[#f1f5f3] text-[#687780]'}`}>{trip.status}</span></div>
                          <p className="mb-0 mt-1 flex items-center gap-1 text-[11px] text-[#687780]"><span className="material-symbols-outlined text-sm">place</span>{trip.destination}</p>
                          <p className="mb-0 mt-2 text-[10px] text-[#687780]">{trip.id}<span className="mx-1.5 text-[#b3bdbc]">·</span>{trip.stops.length} stops</p>
                        </div>
                      </div>
                      <label className="flex items-center gap-2 text-[10px] font-semibold text-[#687780]">Vehicle
                        <select className="max-w-[145px] rounded border border-[#dce4e5] bg-white px-2 py-2 text-[11px] text-[#192b35] disabled:cursor-not-allowed disabled:bg-[#f4f7f5]" aria-label={`Assign vehicle to ${trip.id}`} title={dispatcher ? undefined : 'Sign in with Google to make live changes'} value={trip.vehicle} disabled={terminal || !dispatcher} onChange={(event) => assignVehicle(trip, event.target.value)}>
                          {[...new Set([...vehicles, trip.vehicle])].map((option) => <option key={option}>{option}</option>)}
                        </select>
                      </label>
                    </div>

                    <div className="mt-3 rounded bg-[#f4f7f5] px-3 py-2.5">
                      <div className="mb-2 flex items-center justify-between gap-2"><span className="text-[9px] font-bold uppercase tracking-wide text-[#687780]">Stop progress</span><span className="text-[9px] text-[#687780]">{Math.min(trip.nextStopIndex, trip.stops.length)} / {trip.stops.length} arrivals</span></div>
                      <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                        {trip.stops.map((stop, index) => <span className={`inline-flex items-center gap-1 text-[10px] ${index < trip.nextStopIndex ? 'font-semibold text-[#087a59]' : index === trip.nextStopIndex && !terminal ? 'font-semibold text-[#126b91]' : 'text-[#849098]'}`} key={`${trip.id}-${stop}`}><i className={`size-1.5 rounded-full ${index < trip.nextStopIndex ? 'bg-[#1c9a6d]' : index === trip.nextStopIndex && !terminal ? 'bg-[#126b91]' : 'bg-[#cbd4d2]'}`} />{stop}{index < trip.stops.length - 1 && <span className="ml-1 text-[#b3bdbc]">/</span>}</span>)}
                      </div>
                    </div>

                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      {!trip.departed && !terminal && <button className="inline-flex items-center gap-1.5 rounded bg-[#126b91] px-3 py-2 text-[10px] font-semibold text-white hover:bg-[#0e5a7b] disabled:cursor-not-allowed disabled:opacity-50" title={dispatcher ? undefined : 'Sign in with Google to make live changes'} disabled={!dispatcher} type="button" onClick={() => recordDeparture(trip)}><span className="material-symbols-outlined text-sm">departure_board</span>Record departure</button>}
                      {trip.departed && !terminal && nextStop && <button className="inline-flex items-center gap-1.5 rounded bg-[#087a59] px-3 py-2 text-[10px] font-semibold text-white hover:bg-[#066447] disabled:cursor-not-allowed disabled:opacity-50" title={dispatcher ? undefined : 'Sign in with Google to make live changes'} disabled={!dispatcher} type="button" onClick={() => recordStopArrival(trip)}><span className="material-symbols-outlined text-sm">where_to_vote</span>Arrived: {nextStop}</button>}
                      {!terminal && trip.status !== 'Delayed' && <button className="inline-flex items-center gap-1 rounded border border-[#ead9b5] bg-white px-3 py-2 text-[10px] font-semibold text-[#86601d] hover:bg-[#fff7e8] disabled:cursor-not-allowed disabled:opacity-50" title={dispatcher ? undefined : 'Sign in with Google to make live changes'} disabled={!dispatcher} type="button" onClick={() => updateStatus(trip, 'Delayed')}><span className="material-symbols-outlined text-sm">warning</span>Mark delayed</button>}
                      {!terminal && <button className="inline-flex items-center gap-1 rounded border border-[#ecd1cf] bg-white px-3 py-2 text-[10px] font-semibold text-[#a33c36] hover:bg-[#fcebea] disabled:cursor-not-allowed disabled:opacity-50" title={dispatcher ? undefined : 'Sign in with Google to make live changes'} disabled={!dispatcher} type="button" onClick={() => updateStatus(trip, 'Canceled')}><span className="material-symbols-outlined text-sm">block</span>Cancel</button>}
                      {trip.status === 'Delayed' && !terminal && <button className="inline-flex items-center gap-1 rounded border border-[#b7e2cf] bg-white px-3 py-2 text-[10px] font-semibold text-[#087a59] hover:bg-[#e8f4ed] disabled:cursor-not-allowed disabled:opacity-50" title={dispatcher ? undefined : 'Sign in with Google to make live changes'} disabled={!dispatcher} type="button" onClick={() => updateStatus(trip, trip.departed ? 'In progress' : 'Scheduled')}><span className="material-symbols-outlined text-sm">check_circle</span>Clear delay</button>}
                    </div>
                  </article>
                )
              })}
            </div>
          </section>

          <aside className="flex flex-col gap-5 lg:sticky lg:top-[84px]">
            <section className="border border-[#dce4e5] bg-white p-4" aria-labelledby="create-heading">
              <div className="mb-4 flex items-center gap-2"><span className="material-symbols-outlined text-[#126b91]">add_circle</span><div><h2 id="create-heading" className="m-0 font-['Space_Grotesk',sans-serif] text-base font-semibold">Create trip</h2><p className="mb-0 mt-0.5 text-[10px] text-[#687780]">Add a run to the dispatch board</p></div></div>
              <form className="flex flex-col gap-3" onSubmit={createTrip}>
                <label className="flex flex-col gap-1 text-[10px] font-semibold text-[#687780]">Route name<input className="h-9 rounded border border-[#dce4e5] bg-white px-2.5 text-xs font-normal text-[#192b35] outline-none focus:border-[#3987a3] disabled:bg-[#f4f7f5]" value={routeName} onChange={(event) => setRouteName(event.target.value)} placeholder="e.g. 34 South Michigan" required disabled={!dispatcher} /></label>
                <label className="flex flex-col gap-1 text-[10px] font-semibold text-[#687780]">Final stop<input className="h-9 rounded border border-[#dce4e5] bg-white px-2.5 text-xs font-normal text-[#192b35] outline-none focus:border-[#3987a3] disabled:bg-[#f4f7f5]" value={destination} onChange={(event) => setDestination(event.target.value)} placeholder="e.g. 95th Red Line Station" required disabled={!dispatcher} /></label>
                <label className="flex flex-col gap-1 text-[10px] font-semibold text-[#687780]">Intermediate stops <span className="font-normal">(comma-separated)</span><input className="h-9 rounded border border-[#dce4e5] bg-white px-2.5 text-xs font-normal text-[#192b35] outline-none focus:border-[#3987a3] disabled:bg-[#f4f7f5]" value={stopsText} onChange={(event) => setStopsText(event.target.value)} placeholder="Roosevelt, 35th Street" disabled={!dispatcher} /></label>
                <label className="flex flex-col gap-1 text-[10px] font-semibold text-[#687780]">Assign vehicle<select className="h-9 rounded border border-[#dce4e5] bg-white px-2.5 text-xs font-normal text-[#192b35] outline-none focus:border-[#3987a3] disabled:bg-[#f4f7f5]" value={newVehicle} onChange={(event) => setNewVehicle(event.target.value)} disabled={!dispatcher}>{vehicles.map((option) => <option key={option}>{option}</option>)}</select></label>
                <button className="mt-1 inline-flex h-10 items-center justify-center gap-2 rounded bg-[#126b91] px-3 text-xs font-semibold text-white hover:bg-[#0e5a7b] disabled:cursor-not-allowed disabled:opacity-60" title={dispatcher ? undefined : 'Sign in with Google to save live changes'} disabled={!dispatcher || authLoading} type="submit"><span className="material-symbols-outlined text-base">add</span>Create trip</button>
              </form>
            </section>

            <section className="border border-[#dce4e5] bg-white p-4" aria-labelledby="activity-heading">
              <div className="mb-3 flex items-center justify-between"><div><h2 id="activity-heading" className="m-0 font-['Space_Grotesk',sans-serif] text-base font-semibold">Activity log</h2><p className="mb-0 mt-0.5 text-[10px] text-[#687780]">Latest dispatcher events</p></div><span className="material-symbols-outlined text-[#687780]" aria-hidden="true">history</span></div>
              <ol className="m-0 flex list-none flex-col gap-3 border-l border-[#dce4e5] pl-3">
                {activities.slice(0, 8).map((activity) => <li className="relative text-[10px] leading-relaxed text-[#52636b] before:absolute before:top-[5px] before:-left-[16px] before:size-[7px] before:rounded-full before:border-2 before:border-white before:bg-[#3987a3]" key={activity.id}><time className="mr-1.5 font-semibold tabular-nums text-[#126b91]">{activity.time}</time>{activity.message}</li>)}
              </ol>
            </section>
          </aside>
        </div>
      </main>
    </div>
  )
}