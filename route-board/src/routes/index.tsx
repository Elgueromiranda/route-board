import { useEffect, useMemo, useState } from 'react'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { LiveClock } from '../components/LiveClock'

type Stop = {
  stop_sequence: number
  departure_time: string
  stop?: {
    stop_id?: string | null
    stop_name?: string | null
    stop_desc?: string | null
    stop_lat?: string | null
    stop_lon?: string | null
  } | null
}

type Shuttle = {
  code?: string
  route_id?: string
  route_color?: string
  route_short_name?: string
  route_long_name: string
  vehicle?: {
    id: number | string
    label: string | null
    status?: string
  } | null
  trip: {
    trip_id?: string
    service_id?: string
    stops: Stop[]
  }
  bay?: string | null
  delayed?: boolean
  status?: string
}

type RouteEstimate = {
  route_id: string
  available: boolean
  duration_seconds?: number
  distance_meters?: number
  fetched_at?: string
  cached?: boolean
  stale?: boolean
}

/* ---------- time helpers ---------- */

function parseScheduleTime(value: string) {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$/i)
  if (!match) return null
  let hours = Number(match[1])
  const suffix = match[4]?.toUpperCase()
  if (suffix === 'AM' && hours === 12) hours = 0
  if (suffix === 'PM' && hours < 12) hours += 12
  return { hours, minutes: Number(match[2]), seconds: Number(match[3] ?? 0) }
}

function scheduleSeconds(value: string) {
  const parsed = parseScheduleTime(value)
  return parsed
    ? parsed.hours * 3600 + parsed.minutes * 60 + parsed.seconds
    : Number.POSITIVE_INFINITY
}

function scheduleDate(value: string, reference: Date) {
  const parsed = parseScheduleTime(value)
  if (!parsed) return null
  const d = new Date(reference)
  d.setHours(0, 0, 0, 0)
  d.setHours(parsed.hours, parsed.minutes, parsed.seconds, 0)
  return d
}

function secondsToClock(totalSeconds: number) {
  const s = ((totalSeconds % 86400) + 86400) % 86400
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = Math.floor(s % 60)
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

function hhmm(value?: string | null) {
  if (!value) return '—'
  return value.slice(0, 5)
}

function getOrderedStops(shuttle: Shuttle): Stop[] {
  return [...shuttle.trip.stops].sort((a, b) => a.stop_sequence - b.stop_sequence)
}

function getShuttleKey(shuttle: Shuttle) {
  return (
    shuttle.route_id ??
    shuttle.code ??
    `${shuttle.route_short_name}-${shuttle.route_long_name}`
  )
}

/* ---------- estimate distribution ---------- */

/**
 * Given the ordered stops and the Geoapify total duration, compute an
 * estimated `departure_time` for each stop by scaling the schedule offsets.
 */
function distributeEstimate(stops: Stop[], totalDurationSeconds: number): Record<number, string> {
  if (stops.length === 0 || !Number.isFinite(totalDurationSeconds) || totalDurationSeconds <= 0) {
    return {}
  }

  const firstSec = scheduleSeconds(stops[0].departure_time)
  const lastSec = scheduleSeconds(stops[stops.length - 1].departure_time)
  const scheduleSpan = lastSec - firstSec

  // If schedule has no span (single stop / all same time), just use first time.
  if (!Number.isFinite(scheduleSpan) || scheduleSpan <= 0) {
    const only = stops[0].departure_time
    return Object.fromEntries(stops.map((s) => [s.stop_sequence, only]))
  }

  const scale = totalDurationSeconds / scheduleSpan

  return Object.fromEntries(
    stops.map((s) => {
      const offset = scheduleSeconds(s.departure_time) - firstSec
      const estimated = firstSec + offset * scale
      return [s.stop_sequence, secondsToClock(estimated)]
    })
  )
}

/* ---------- live ETA from a given departure time ---------- */

function etaFromTime(time: string | undefined, clock: Date) {
  if (!time) return { label: '—', minutes: Number.POSITIVE_INFINITY }
  const scheduled = scheduleDate(time, clock)
  if (!scheduled) return { label: '—', minutes: Number.POSITIVE_INFINITY }
  const minutes = Math.ceil((scheduled.getTime() - clock.getTime()) / 60_000)
  if (minutes < 0) return { label: 'Departed', minutes }
  if (minutes === 0) return { label: 'Due now', minutes: 0 }
  return { label: `${minutes} min`, minutes }
}

/* ---------- route ---------- */

export const Route = createFileRoute('/')({ component: Home })

function Home() {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'on_time' | 'delayed'>('all')
  const [clock, setClock] = useState(() => new Date())
  const [selectedShuttleKey, setSelectedShuttleKey] = useState<string | null>(null)
  const queryClient = useQueryClient()

  /* ------- trips list ------- */
  const { data: shuttles = [] } = useQuery<Shuttle[]>({
    queryKey: ['trips'],
    queryFn: async () => {
      const res = await fetch('http://localhost:3000/api/v1/trips')
      if (!res.ok) throw new Error('Failed to fetch trips')
      return res.json()
    },
  })

  /* ------- search + filter ------- */
  const normalizedSearch = searchTerm.trim().toLowerCase()
  const filteredShuttles = useMemo(() => {
    return shuttles.filter((s) => {
      const finalStopDescription = s.trip.stops.at(-1)?.stop?.stop_desc ?? ''
      const searchable =
        `${s.route_short_name ?? ''} ${s.route_long_name} ${finalStopDescription}`.toLowerCase()
      if (!searchable.includes(normalizedSearch)) return false
      if (statusFilter === 'on_time') return !s.delayed
      if (statusFilter === 'delayed') return !!s.delayed
      return true
    })
  }, [shuttles, normalizedSearch, statusFilter])

  const selectedShuttle =
    filteredShuttles.find((s) => getShuttleKey(s) === selectedShuttleKey) ?? filteredShuttles[0]

  const selectedRouteId = selectedShuttle?.route_id

  /* ------- per-route estimate (Geoapify) ------- */
  const { data: estimate, isError: estimateError } = useQuery<RouteEstimate>({
    queryKey: ['estimate', selectedRouteId],
    enabled: !!selectedRouteId,
    queryFn: async () => {
      const res = await fetch(`http://localhost:3000/api/v1/routes/${selectedRouteId}/estimate`)
      if (!res.ok) throw new Error('Failed to fetch estimate')
      return res.json()
    },
    staleTime: 5 * 60_000,
  })

  const estimateAvailable =
    !!estimate && estimate.available && !estimateError && (estimate.duration_seconds ?? 0) > 0

  const orderedStops = selectedShuttle ? getOrderedStops(selectedShuttle) : []
  const estimatedBySeq = useMemo(() => {
    if (!estimateAvailable || !estimate?.duration_seconds) return {}
    return distributeEstimate(orderedStops, estimate.duration_seconds)
  }, [estimateAvailable, estimate?.duration_seconds, orderedStops])

  /* ------- "next stop" uses estimated time when available ------- */
  const nextStop = useMemo(() => {
    if (!selectedShuttle) return undefined
    const stops = getOrderedStops(selectedShuttle)
    const nowSec = clock.getHours() * 3600 + clock.getMinutes() * 60 + clock.getSeconds()
    return stops.find((s) => {
      const est = estimatedBySeq[s.stop_sequence]
      const ref = est ?? s.departure_time
      return scheduleSeconds(ref) >= nowSec
    })
  }, [selectedShuttle, clock, estimatedBySeq])

  /* ------- clock ------- */
  useEffect(() => {
    const timer = window.setInterval(() => setClock((c) => new Date(c.getTime() + 1000)), 1000)
    return () => window.clearInterval(timer)
  }, [])

  /* ------- SSE: invalidate trips + selected estimate ------- */
  useEffect(() => {
    const es = new EventSource('http://localhost:3000/api/v1/trips/stream')
    es.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data) as { trip_id?: string; route_id?: string }
        if (data.trip_id) queryClient.invalidateQueries({ queryKey: ['trips'] })
        if (data.route_id) queryClient.invalidateQueries({ queryKey: ['estimate', data.route_id] })
      } catch {
        /* ignore malformed */
      }
    }
    es.onerror = (err) => console.warn('SSE error, will auto-reconnect', err)
    return () => es.close()
  }, [queryClient])

  /* ------- helper for a stop: scheduled vs estimated ------- */
  function stopTimes(stop: Stop) {
    const estimated = estimatedBySeq[stop.stop_sequence]
    return {
      scheduled: stop.departure_time,
      estimated: estimated ?? null,
      effective: estimated ?? stop.departure_time,
      hasEstimate: !!estimated,
    }
  }

  const nextStopTimes = nextStop ? stopTimes(nextStop) : null
  const nextEta = nextStopTimes ? etaFromTime(nextStopTimes.effective, clock) : null

  return (
    <div className="min-h-screen bg-[#f4f7f5] font-['Work_Sans',sans-serif] text-[14px] text-[#192b35]">
      <header className="sticky top-0 z-10 flex min-h-[68px] flex-wrap items-center justify-between gap-3 border-b border-[#dce4e5] bg-white/95 px-4 py-2.5 md:flex-nowrap md:px-6 xl:px-[max(24px,calc((100vw-1440px)/2))]">
        <a className="flex min-w-0 items-center gap-2.5 text-inherit no-underline sm:min-w-[190px]" href="#top" aria-label="RouteBoard home">
          <span className="material-symbols-outlined grid size-[42px] shrink-0 place-items-center rounded-lg bg-[#126b91] text-2xl text-white">directions_bus</span>
          <span className="flex flex-col gap-[3px]">
            <strong className="font-['Space_Grotesk',sans-serif] text-lg font-semibold leading-none">RouteBoard</strong>
            <small className="text-[8px] font-semibold uppercase tracking-[.07em] text-[#687780] sm:text-[10px]">Shuttle dispatch & arrival</small>
          </span>
        </a>
        <div className="flex min-w-0 items-center justify-end gap-2 sm:gap-3">
          <Link className="rounded px-3 py-2 text-xs font-semibold text-[#126b91] no-underline hover:bg-[#f1f5f3]" to="/dispatch">Dispatch</Link>
          <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-[#b7e2cf] bg-[#e1f4eb] px-2 py-2 text-[9px] font-semibold uppercase tracking-wide text-[#126a4d] sm:text-[11px]">
            <i className="size-[7px] rounded-full bg-[#1c9a6d]" />System live
          </span>
          <span className="hidden items-center gap-1.5 whitespace-nowrap text-[11px] font-semibold tabular-nums text-[#687780] sm:inline-flex">
            <span className="material-symbols-outlined text-[17px]">schedule</span>
            <LiveClock time={clock} />
          </span>
        </div>
      </header>

      <main id="top" className="mx-auto w-[calc(100%-28px)] max-w-[1392px] py-5 sm:w-[calc(100%-32px)] sm:py-6 lg:w-[calc(100%-48px)] lg:py-[30px]">
        <section className="mb-6 flex flex-col items-start justify-between gap-4 lg:flex-row lg:items-end lg:gap-6" aria-labelledby="page-title">
          <div>
            <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[.1em] text-[#126b91]">
              <i className="size-[7px] rounded-full bg-[#1c9a6d]" />Live digital concourse board
            </div>
            <h1 id="page-title" className="my-2 font-['Space_Grotesk',sans-serif] text-[27px] leading-tight font-semibold sm:text-[32px]">Public Terminal Arrivals</h1>
            <p className="m-0 max-w-[630px] text-xs leading-relaxed text-[#687780] sm:text-sm">
              Real-time arrival estimates, current platform gates, and stop progression for campus and downtown connections.
            </p>
          </div>
          <div className="flex w-full gap-1 rounded-lg border border-[#dce4e5] bg-[#eaf0ed] p-[5px] lg:w-auto" aria-label="Hub information">
            <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-md bg-white px-2 py-2 sm:min-w-[125px] sm:px-3">
              <span className="text-[9px] text-[#687780] sm:text-[10px]">Active shuttles</span>
              <strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[13px] leading-tight font-semibold sm:text-base">{shuttles.length} units</strong>
            </div>
            <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-md bg-white px-2 py-2 sm:min-w-[125px] sm:px-3">
              <span className="text-[9px] text-[#687780] sm:text-[10px]">Avg frequency</span>
              <strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[13px] leading-tight font-semibold text-[#087a59] sm:text-base">6–8 min</strong>
            </div>
          </div>
        </section>

        <section className="mb-5 flex flex-col justify-between gap-3 rounded-lg border border-[#dce4e5] bg-white p-3 lg:flex-row lg:items-center" aria-label="Arrival filters">
          <label className="flex h-[42px] min-w-0 flex-1 items-center gap-2.5 rounded-md bg-[#f1f5f3] px-3 text-[#687780]">
            <span className="material-symbols-outlined text-xl">search</span>
            <input
              className="w-full min-w-0 border-0 bg-transparent text-[13px] text-[#192b35] outline-none placeholder:text-[#849098]"
              type="search"
              placeholder="Search shuttle line, or destination"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </label>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <div className="flex items-center justify-between gap-0.5 rounded-md bg-[#f1f5f3] p-[3px]" aria-label="Filter shuttle status">
              {(['all', 'on_time', 'delayed'] as const).map((value) => (
                <button
                  key={value}
                  className={`min-h-[34px] flex-1 rounded px-2 text-[10px] font-semibold sm:px-[11px] sm:text-[11px] ${
                    statusFilter === value ? 'bg-white text-[#192b35] shadow-sm' : 'text-[#687780]'
                  }`}
                  type="button"
                  onClick={() => setStatusFilter(value)}
                >
                  {value === 'all' ? 'All shuttles' : value === 'on_time' ? 'On time' : 'Delayed'}
                </button>
              ))}
            </div>
          </div>
        </section>

        <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1.9fr)_minmax(340px,.95fr)] lg:gap-[18px]" id="arrivals">
          <section className="flex min-w-0 flex-col gap-2" aria-label="Upcoming shuttle arrivals">
            <div className="hidden grid-cols-[minmax(175px,2.25fr)_minmax(78px,.8fr)_minmax(66px,.68fr)_minmax(62px,.62fr)_minmax(82px,.85fr)] items-center gap-1 px-3 pb-px text-[9px] font-bold uppercase tracking-[.08em] text-[#687780] md:grid lg:grid-cols-[minmax(220px,2.25fr)_minmax(90px,.8fr)_minmax(75px,.68fr)_minmax(75px,.62fr)_minmax(100px,.85fr)] lg:gap-2">
              <span>Shuttle route & destination</span>
              <span className="text-center">Vehicle</span>
              <span className="text-center">Schedule</span>
              <span className="text-right">Live ETA</span>
              <span className="text-right">Route map</span>
            </div>

            {filteredShuttles.map((shuttle) => {
              const stops = getOrderedStops(shuttle)
              const nowSec = clock.getHours() * 3600 + clock.getMinutes() * 60 + clock.getSeconds()
              const rowNext = stops.find((s) => {
                const est = estimatedBySeq[s.stop_sequence] // only for selected; otherwise fall back
                return scheduleSeconds(est ?? s.departure_time) >= nowSec
              })
              const selected = selectedShuttle != null && getShuttleKey(shuttle) === getShuttleKey(selectedShuttle)
              const rowEffective = rowNext
                ? estimatedBySeq[rowNext.stop_sequence] ?? rowNext.departure_time
                : undefined
              const eta = etaFromTime(rowEffective, clock)
              const isDelayed = !!shuttle.delayed
              const statusLabel = shuttle.status ?? (isDelayed ? 'delayed' : 'scheduled')

              return (
                <article
                  key={getShuttleKey(shuttle)}
                  className={`grid min-h-[85px] grid-cols-[minmax(0,1fr)_auto] items-center gap-x-2 gap-y-2 rounded-lg border bg-white p-[11px] transition-shadow md:grid-cols-[minmax(175px,1.8fr)_minmax(78px,.72fr)_minmax(66px,.62fr)_minmax(62px,.55fr)_minmax(82px,.72fr)] md:gap-1 md:p-2 lg:grid-cols-[minmax(220px,2.25fr)_minmax(90px,.8fr)_minmax(75px,.68fr)_minmax(75px,.62fr)_minmax(100px,.85fr)] lg:gap-2 lg:px-3 ${
                    selected ? 'border-[#3987a3] shadow-[inset_0_0_0_1px_#3987a3]' : 'border-[#e5ebea]'
                  }`}
                >
                  <div className="col-span-2 flex min-w-0 items-center gap-2 md:col-span-1 md:gap-2.5 lg:gap-[11px]">
                    <span
                      style={{ backgroundColor: shuttle.route_color }}
                      className="grid size-[42px] shrink-0 place-items-center rounded-lg bg-[#126b91] text-white"
                    >
                      <span className="material-symbols-outlined inline-block scale-150 text-2xl leading-none">directions_bus</span>
                    </span>
                    <span className="flex min-w-0 flex-col gap-[5px]">
                      <span className="flex items-center gap-1.5 overflow-hidden font-['Space_Grotesk',sans-serif] text-xs leading-tight font-semibold whitespace-nowrap lg:text-sm">
                        {shuttle.route_long_name}
                      </span>
                      <span className="overflow-hidden text-[11px] text-ellipsis whitespace-nowrap text-[#687780]">
                        {rowNext
                          ? `Next: ${rowNext.stop?.stop_name ?? rowNext.stop?.stop_desc ?? `Stop ${rowNext.stop_sequence}`}`
                          : 'No scheduled stops'}
                      </span>
                    </span>
                  </div>

                  <div className="flex justify-start md:justify-center">
                    <span
                      className="inline-flex items-center gap-1 whitespace-nowrap rounded-[5px] bg-[#f1f5f3] px-2 py-[7px] text-[10px] font-semibold"
                      title={shuttle.vehicle?.status ?? undefined}
                    >
                      {shuttle.vehicle?.label ?? (shuttle.vehicle?.id != null ? `#${shuttle.vehicle.id}` : shuttle.bay ?? '—')}
                    </span>
                  </div>

                  <div className="flex flex-col items-start gap-1 md:items-center">
                    <strong className="font-['Space_Grotesk',sans-serif] text-[15px] font-semibold tabular-nums">
                      {rowNext ? hhmm(rowNext.departure_time) : '—'}
                    </strong>
                    <small className="hidden text-[9px] text-[#687780] md:block">Scheduled</small>
                  </div>

                  <div className={`flex flex-col items-end gap-[5px] ${isDelayed ? 'text-[#a75a16]' : 'text-[#087a59]'}`}>
                    <strong className="font-['Space_Grotesk',sans-serif] text-[20px] leading-[.9] font-semibold">
                      {eta.label}
                    </strong>
                    <span className="inline-flex items-center gap-[5px] whitespace-nowrap text-[9px] font-bold uppercase">
                      {!isDelayed && <i className="size-1.5 rounded-full bg-current" />}
                      {statusLabel}
                    </span>
                  </div>

                  <button
                    className={`col-span-2 flex min-h-[34px] w-full items-center justify-center gap-0.5 rounded px-2 text-[10px] font-semibold whitespace-nowrap md:col-span-1 md:px-1 md:text-[9px] lg:px-2 lg:text-[10px] ${
                      selected ? 'bg-[#126b91] text-white' : 'bg-[#f1f5f3] text-[#192b35]'
                    }`}
                    type="button"
                    onClick={() => setSelectedShuttleKey(getShuttleKey(shuttle))}
                  >
                    {selected ? 'Selected' : 'View stops'}
                    <span className="material-symbols-outlined text-base">chevron_right</span>
                  </button>
                </article>
              )
            })}
          </section>

          <aside
            className="flex flex-col gap-4 rounded-lg border border-[#dce4e5] bg-white p-3.5 sm:p-[17px] lg:sticky lg:top-[84px]"
            aria-label="Selected shuttle trip details"
          >
            <div className="flex items-start justify-between gap-2.5">
              <div>
                <span className="flex items-center gap-2 text-[9px] font-bold uppercase tracking-[.1em] text-[#126b91]">
                  <i className="size-[7px] rounded-full bg-[#1c9a6d]" />Live trip track
                </span>
                <h2 className="my-2 font-['Space_Grotesk',sans-serif] text-[17px] leading-tight font-semibold">
                  {selectedShuttle?.route_long_name ?? 'Select a shuttle'}
                </h2>
                <p className="m-0 text-[10px] text-[#687780]">
                  {selectedShuttle?.vehicle?.label ??
                    (selectedShuttle?.vehicle?.id ? `Vehicle #${selectedShuttle.vehicle.id}` : 'Vehicle assignment unavailable')}
                  {selectedShuttle?.trip?.trip_id ? ` · Trip ${selectedShuttle.trip.trip_id}` : ''}
                </p>
              </div>
            </div>

            <div className="grid grid-cols-[1.15fr_.8fr_.8fr] items-center rounded-md bg-[#f1f5f3] px-1 py-[11px]">
              <div className="flex min-w-0 flex-col gap-[5px] border-r border-[#d5dfdc] px-[5px] sm:px-[7px]">
                <span className="text-[8px] text-[#687780] sm:text-[9px]">Vehicle</span>
                <strong className="overflow-hidden text-ellipsis whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold sm:text-xs">
                  {selectedShuttle?.vehicle?.label ?? 'Not assigned'}
                </strong>
              </div>
              <div className="flex min-w-0 flex-col gap-[5px] border-r border-[#d5dfdc] px-[5px] sm:px-[7px]">
                <span className="text-[8px] text-[#687780] sm:text-[9px]">Next stop</span>
                <strong className="overflow-hidden text-ellipsis whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold text-[#087a59] sm:text-xs">
                  {nextStop?.stop?.stop_name ?? nextStop?.stop?.stop_desc ?? '—'}
                </strong>
              </div>
              <div className="flex min-w-0 flex-col gap-[5px] px-[5px] sm:px-[7px]">
                <span className="text-[8px] text-[#687780] sm:text-[9px]">ETA</span>
                <strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold text-[#087a59] sm:text-xs">
                  {nextEta?.label ?? '—'}
                </strong>
              </div>
            </div>

            {!estimateAvailable && (
              <p className="m-0 rounded bg-[#fff6ea] px-2 py-1.5 text-[9px] text-[#a75a16]">
                Road estimate unavailable — showing scheduled times.
              </p>
            )}

            <div>
              <h3 className="mb-[15px] text-[9px] font-bold uppercase tracking-[.08em] text-[#687780]">Sequential stop milestones</h3>
              <div className="relative max-h-[224px] overflow-y-auto overscroll-contain pr-2 pl-[21px] [scrollbar-gutter:stable] before:absolute before:top-[9px] before:bottom-[10px] before:left-[6px] before:w-px before:bg-[#cbd7d6]">
                {selectedShuttle &&
                  orderedStops.map((stop) => {
                    const times = stopTimes(stop)
                    const effective = times.effective
                    const scheduledDate = scheduleDate(effective, clock)
                    const passed = scheduledDate !== null && scheduledDate < clock
                    const nextIndex = orderedStops.findIndex((entry) => {
                      const ref = estimatedBySeq[entry.stop_sequence] ?? entry.departure_time
                      return scheduleSeconds(ref) >= clock.getHours() * 3600 + clock.getMinutes() * 60 + clock.getSeconds()
                    })
                    const index = orderedStops.findIndex((e) => e.stop_sequence === stop.stop_sequence)
                    const current = !passed && index === nextIndex
                    const stopName = stop.stop?.stop_name ?? stop.stop?.stop_desc ?? `Stop ${stop.stop_sequence}`
                    const timeLabel = scheduledDate
                      ? scheduledDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                      : hhmm(effective)

                    return (
                      <div
                        className={`relative grid min-h-[38px] grid-cols-[minmax(0,1fr)_auto] items-center gap-1.5 ${
                          current ? '-my-[5px] -ml-2 rounded bg-[#edf5f6] px-2 py-[7px]' : ''
                        }`}
                        key={`${selectedShuttle.trip.trip_id ?? getShuttleKey(selectedShuttle)}-${stop.stop_sequence}`}
                      >
                        <span
                          className={`material-symbols-outlined absolute top-px -left-[22px] z-[1] grid size-[15px] place-items-center rounded-full ${
                            passed
                              ? 'bg-[#087a59] text-[11px] text-white'
                              : current
                              ? 'left-[-15px] top-2 bg-[#126b91] text-[13px] text-white'
                              : 'bg-white text-[13px] text-[#6e7c80]'
                          }`}
                        >
                          {passed ? 'check' : current ? 'sync' : 'circle'}
                        </span>
                        <div className="flex min-w-0 flex-col gap-1">
                          <strong
                            className={`overflow-hidden text-[11px] font-semibold text-ellipsis whitespace-nowrap ${
                              passed ? 'text-[#718087] line-through' : current ? 'text-[#126b91]' : ''
                            }`}
                          >
                            {stopName}
                            {current && (
                              <b className="ml-1 rounded-[3px] bg-[#087a59] px-1 py-[3px] font-['Work_Sans',sans-serif] text-[8px] font-bold text-white uppercase">
                                Next
                              </b>
                            )}
                          </strong>
                          <small className="text-[9px] text-[#687780]">
                            {passed
                              ? 'Scheduled time passed'
                              : current
                              ? `Due ${etaFromTime(effective, clock).label}`
                              : `Stop ${stop.stop_sequence}`}
                          </small>
                        </div>
                        <span className="flex flex-col items-end gap-1">
                          <strong className={`font-['Space_Grotesk',sans-serif] text-[11px] font-semibold ${current ? 'text-[#126b91]' : ''}`}>
                            {timeLabel}
                          </strong>
                          <small className={`text-[9px] ${passed ? 'text-[#087a59]' : current ? 'text-[#126b91]' : 'text-[#687780]'}`}>
                            {times.hasEstimate ? 'Est.' : 'Sched.'} {hhmm(times.scheduled)}
                          </small>
                        </span>
                      </div>
                    )
                  })}
                {!selectedShuttle && <p className="m-0 text-xs text-[#687780]">No matching live trip is available.</p>}
              </div>
            </div>

            <div className="flex flex-wrap justify-between gap-2 border-t border-[#e5ebea] pt-3 text-[9px] text-[#687780]">
              <span className="flex items-center gap-1">
                <span className="material-symbols-outlined text-[15px] text-[#126b91]">wifi</span>High-speed WiFi
              </span>
              <span className="flex items-center gap-1">
                <span className="material-symbols-outlined text-[15px] text-[#126b91]">accessible</span>ADA ramp
              </span>
            </div>
          </aside>
        </div>

        <section className="mt-[18px] flex flex-wrap items-start gap-3 rounded-md border border-[#dce7e2] bg-[#eaf1ed] p-3.5 sm:items-center">
          <span className="material-symbols-outlined grid size-[34px] shrink-0 place-items-center rounded-md bg-[#d9eaf0] text-[#126b91]">info</span>
          <div className="min-w-0 flex-1 basis-[calc(100%-50px)] sm:basis-0">
            <strong className="text-xs">Scheduled bay maintenance tonight</strong>
            <p className="mt-1 mb-0 text-[11px] leading-relaxed text-[#687780]">
              Starting at 22:00, shuttles departing from Bay 01 and 02 will reroute through North Plaza Gate 8.
            </p>
          </div>
          <a className="ml-[47px] whitespace-nowrap rounded bg-white px-3 py-2 text-[10px] font-semibold text-[#192b35] no-underline sm:ml-0" href="#maintenance">
            Learn more
          </a>
        </section>
      </main>

      <footer className="flex min-h-[60px] flex-wrap items-center gap-x-3 gap-y-2 border-t border-[#dce4e5] bg-white px-4 py-3 sm:px-6 xl:px-[max(24px,calc((100vw-1440px)/2))]">
        <strong className="font-['Space_Grotesk',sans-serif] text-base font-semibold text-[#126b91]">RouteBoard</strong>
        <span className="text-[9px] text-[#687780] sm:text-[10px]">© 2025 Transit Operations Fleet Management</span>
        <span className="flex w-full flex-wrap items-center gap-[7px] text-[9px] text-[#687780] sm:ml-auto sm:w-auto sm:text-[10px]">
          <i className="size-1.5 rounded-full bg-[#1c9a6d]" />
          Telemetry latency: 120ms <b className="text-[#a3adb0]">·</b> Transit Feed GTFS-RT v2.4
        </span>
      </footer>
    </div>
  )
}