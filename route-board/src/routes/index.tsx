import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({ component: Home })

const shuttles = [
  {
    code: 'BX', label: 'Line', name: 'Blue Express', tag: 'Tech',
    detail: 'via 4th Ave & Medical Quad', corridor: 'Tech Campus', bay: '04',
    scheduled: '14:40', eta: '3', status: 'On time', color: 'blue',
  },
  {
    code: 'GL', label: 'Loop', name: 'Green Circulator',
    detail: 'North Campus · Library Mall', corridor: 'Metro West', bay: '02',
    scheduled: '14:45', eta: '8', status: 'On time', color: 'green',
  },
  {
    code: 'RX', label: 'Air', name: 'Airport Flyer', tag: 'Express',
    detail: 'Terminals 1 · 2 · Cargo Zone', corridor: 'Air Shuttle', bay: '07',
    scheduled: '14:48', eta: '16', status: '+5 min', color: 'red', delayed: true,
  },
  {
    code: 'CT', label: 'Town', name: 'Westside Connector',
    detail: 'South Ferry · Waterfront Hub', corridor: 'Metro West', bay: '01',
    scheduled: '14:56', eta: '19', status: 'On time', color: 'orange',
  },
  {
    code: 'MD', label: 'Med', name: 'Health Sciences Shuttle', tag: 'Bio',
    detail: "Children's Hospital · Research Complex", corridor: 'Medical District', bay: '05',
    scheduled: '15:02', eta: '24', status: '+4 min', color: 'navy', delayed: true,
  },
  {
    code: 'OB', label: 'Line', name: 'Innovation Orbit',
    detail: 'East Research · Start-up Pavilion', corridor: 'Tech Campus', bay: '03',
    scheduled: '15:15', eta: '33', status: 'On time', color: 'sky',
  },
]

function Home() {
  return (
    <div className="min-h-screen bg-[#f4f7f5] font-['Work_Sans',sans-serif] text-[14px] text-[#192b35]">
      <header className="sticky top-0 z-10 flex min-h-[68px] flex-wrap items-center justify-between gap-3 border-b border-[#dce4e5] bg-white/95 px-4 py-2.5 md:flex-nowrap md:px-6 xl:px-[max(24px,calc((100vw-1440px)/2))]">
        <a className="flex min-w-0 items-center gap-2.5 text-inherit no-underline sm:min-w-[190px]" href="#top" aria-label="RouteBoard home">
          <span className="material-symbols-outlined grid size-[42px] shrink-0 place-items-center rounded-lg bg-[#126b91] text-2xl text-white">directions_bus</span>
          <span className="flex flex-col gap-[3px]"><strong className="font-['Space_Grotesk',sans-serif] text-lg font-semibold leading-none">RouteBoard</strong><small className="text-[8px] font-semibold uppercase tracking-[.07em] text-[#687780] sm:text-[10px]">Shuttle dispatch & arrival</small></span>
        </a>
        <nav className="order-3 flex w-full items-center gap-1 rounded-full border border-[#dce4e5] bg-[#f2f5f3] p-1 md:order-none md:w-auto" aria-label="Main navigation">
          <a className="flex-1 whitespace-nowrap rounded-full bg-[#192b35] px-2 py-2 text-center text-[10px] font-semibold text-white no-underline sm:px-[15px] sm:text-xs" href="#arrivals">Public arrivals</a>
          <a className="flex-1 whitespace-nowrap rounded-full px-2 py-2 text-center text-[10px] font-semibold text-[#687780] no-underline sm:px-[15px] sm:text-xs" href="#dispatch">Dispatcher console</a>
        </nav>
        <div className="flex min-w-0 items-center justify-end gap-2 sm:gap-3">
          <span className="hidden items-center gap-1.5 whitespace-nowrap rounded-full border border-[#dce4e5] px-2.5 py-2 text-[11px] font-semibold uppercase lg:inline-flex"><span className="material-symbols-outlined text-base text-[#126b91]">location_on</span>Central Hub · Bay 4</span>
          <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border border-[#b7e2cf] bg-[#e1f4eb] px-2 py-2 text-[9px] font-semibold uppercase tracking-wide text-[#126a4d] sm:text-[11px]"><i className="size-[7px] rounded-full bg-[#1c9a6d]" />System live</span>
          <span className="hidden items-center gap-1.5 whitespace-nowrap text-[11px] font-semibold tabular-nums text-[#687780] sm:inline-flex"><span className="material-symbols-outlined text-[17px]">schedule</span>14:32:08</span>
          <span className="material-symbols-outlined grid size-[30px] shrink-0 place-items-center rounded-full bg-[#126b91] text-white sm:size-[34px]" aria-label="Account">person</span>
        </div>
      </header>

      <main id="top" className="mx-auto w-[calc(100%-28px)] max-w-[1392px] py-5 sm:w-[calc(100%-32px)] sm:py-6 lg:w-[calc(100%-48px)] lg:py-[30px]">
        <section className="mb-6 flex flex-col items-start justify-between gap-4 lg:flex-row lg:items-end lg:gap-6" aria-labelledby="page-title">
          <div>
            <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[.1em] text-[#126b91]"><i className="size-[7px] rounded-full bg-[#1c9a6d]" />Live digital concourse board</div>
            <h1 id="page-title" className="my-2 font-['Space_Grotesk',sans-serif] text-[27px] leading-tight font-semibold sm:text-[32px]">Public Terminal Arrivals</h1>
            <p className="m-0 max-w-[630px] text-xs leading-relaxed text-[#687780] sm:text-sm">Real-time arrival estimates, current platform gates, and stop progression for campus and downtown connections.</p>
          </div>
          <div className="flex w-full gap-1 rounded-lg border border-[#dce4e5] bg-[#eaf0ed] p-[5px] lg:w-auto" aria-label="Hub information">
            <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-md bg-white px-2 py-2 sm:min-w-[125px] sm:px-3"><span className="text-[9px] text-[#687780] sm:text-[10px]">Active shuttles</span><strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[13px] leading-tight font-semibold sm:text-base">18 units</strong></div>
            <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-md bg-white px-2 py-2 sm:min-w-[125px] sm:px-3"><span className="text-[9px] text-[#687780] sm:text-[10px]">Avg frequency</span><strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[13px] leading-tight font-semibold text-[#087a59] sm:text-base">6–8 min</strong></div>
            <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-md bg-white px-2 py-2 sm:min-w-[125px] sm:px-3"><span className="text-[9px] text-[#687780] sm:text-[10px]">Hub weather</span><strong className="flex items-center gap-1 whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[13px] leading-tight font-semibold sm:text-base"><span className="material-symbols-outlined text-[17px] text-[#a75a16]">wb_sunny</span>68°F</strong></div>
          </div>
        </section>

        <section className="mb-5 flex flex-col justify-between gap-3 rounded-lg border border-[#dce4e5] bg-white p-3 lg:flex-row lg:items-center" aria-label="Arrival filters">
          <label className="flex h-[42px] min-w-0 flex-1 items-center gap-2.5 rounded-md bg-[#f1f5f3] px-3 text-[#687780]">
            <span className="material-symbols-outlined text-xl">search</span>
            <input className="w-full min-w-0 border-0 bg-transparent text-[13px] text-[#192b35] outline-none placeholder:text-[#849098]" type="search" placeholder="Search shuttle line, destination, or platform..." />
          </label>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <label className="relative flex h-[42px] sm:w-[175px]">
              <select className="h-full w-full appearance-none rounded-md bg-[#f1f5f3] px-3 pr-9 text-xs font-semibold text-[#192b35] outline-[#126b91]" defaultValue="all" aria-label="Filter corridor">
                <option value="all">All corridors</option>
                <option>Metro West</option><option>Tech Campus</option>
                <option>Medical District</option><option>Air Shuttle</option>
              </select>
              <span className="material-symbols-outlined pointer-events-none absolute top-1/2 right-2.5 -translate-y-1/2 text-[#687780]">expand_more</span>
            </label>
            <div className="flex items-center justify-between gap-0.5 rounded-md bg-[#f1f5f3] p-[3px]" aria-label="Filter shuttle status">
              <button className="min-h-[34px] flex-1 rounded bg-white px-2 text-[10px] font-semibold text-[#192b35] shadow-sm sm:px-[11px] sm:text-[11px]" type="button">All shuttles</button>
              <button className="min-h-[34px] flex-1 rounded px-2 text-[10px] font-semibold text-[#687780] sm:px-[11px] sm:text-[11px]" type="button">On time</button>
              <button className="min-h-[34px] flex-1 rounded px-2 text-[10px] font-semibold text-[#687780] sm:px-[11px] sm:text-[11px]" type="button">Delayed</button>
            </div>
          </div>
        </section>

        <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1.9fr)_minmax(340px,.95fr)] lg:gap-[18px]" id="arrivals">
          <section className="flex min-w-0 flex-col gap-2" aria-label="Upcoming shuttle arrivals">
            <div className="hidden grid-cols-[minmax(175px,2.25fr)_minmax(78px,.8fr)_minmax(66px,.68fr)_minmax(62px,.62fr)_minmax(82px,.85fr)] items-center gap-1 px-3 pb-px text-[9px] font-bold uppercase tracking-[.08em] text-[#687780] md:grid lg:grid-cols-[minmax(220px,2.25fr)_minmax(90px,.8fr)_minmax(75px,.68fr)_minmax(75px,.62fr)_minmax(100px,.85fr)] lg:gap-2"><span>Shuttle route & destination</span><span className="text-center">Gate / bay</span><span className="text-center">Schedule</span><span className="text-right">Live ETA</span><span className="text-right">Route map</span></div>
            {shuttles.map((shuttle, index) => (
              <article className={`grid min-h-[85px] grid-cols-[minmax(0,1fr)_auto] items-center gap-x-2 gap-y-2 rounded-lg border bg-white p-[11px] transition-shadow md:grid-cols-[minmax(175px,1.8fr)_minmax(78px,.72fr)_minmax(66px,.62fr)_minmax(62px,.55fr)_minmax(82px,.72fr)] md:gap-1 md:p-2 lg:grid-cols-[minmax(220px,2.25fr)_minmax(90px,.8fr)_minmax(75px,.68fr)_minmax(75px,.62fr)_minmax(100px,.85fr)] lg:gap-2 lg:px-3 ${index === 0 ? 'border-[#3987a3] shadow-[inset_0_0_0_1px_#3987a3]' : 'border-[#e5ebea]'}`} key={shuttle.code}>
                <div className="col-span-2 flex min-w-0 items-center gap-2 md:col-span-1 md:gap-2.5 lg:gap-[11px]">
                  <span className={`flex h-[46px] w-[38px] shrink-0 flex-col items-center justify-center gap-[3px] rounded-[7px] text-white lg:w-11 ${shuttle.color === 'blue' ? 'bg-[#126b91]' : shuttle.color === 'green' ? 'bg-[#087a59]' : shuttle.color === 'red' ? 'bg-[#b23d35]' : shuttle.color === 'orange' ? 'bg-[#a75a16]' : shuttle.color === 'navy' ? 'bg-[#354f5d]' : 'bg-[#3382a0]'}`}><strong className="font-['Space_Grotesk',sans-serif] text-[15px] leading-none font-semibold">{shuttle.code}</strong><small className="text-[8px] uppercase tracking-[.08em]">{shuttle.label}</small></span>
                  <span className="flex min-w-0 flex-col gap-[5px]">
                    <span className="flex items-center gap-1.5 overflow-hidden font-['Space_Grotesk',sans-serif] text-xs leading-tight font-semibold whitespace-nowrap lg:text-sm">{shuttle.name}{shuttle.tag && <small className={`rounded-[3px] px-[5px] py-[3px] font-['Work_Sans',sans-serif] text-[9px] leading-none font-semibold uppercase ${shuttle.delayed ? 'bg-[#fbe9e5] text-[#8f332f]' : 'bg-[#e1eff4] text-[#24556b]'}`}>{shuttle.tag}</small>}</span>
                    <span className="overflow-hidden text-[11px] text-ellipsis whitespace-nowrap text-[#687780]">{shuttle.detail}</span>
                  </span>
                </div>
                <div className="flex justify-start md:justify-center"><span className="inline-flex items-center gap-1 whitespace-nowrap rounded-[5px] bg-[#f1f5f3] px-2 py-[7px] text-[10px] font-semibold"><span className="material-symbols-outlined text-[15px] text-[#126b91]">signpost</span>Bay {shuttle.bay}</span></div>
                <div className="flex flex-col items-start gap-1 md:items-center"><strong className="font-['Space_Grotesk',sans-serif] text-[15px] font-semibold tabular-nums">{shuttle.scheduled}</strong><small className="hidden text-[9px] text-[#687780] md:block">Scheduled</small></div>
                <div className={`flex flex-col items-end gap-[5px] ${shuttle.delayed ? 'text-[#a75a16]' : 'text-[#087a59]'}`}>
                  <strong className="font-['Space_Grotesk',sans-serif] text-[25px] leading-[.9] font-semibold">{shuttle.eta}<small className="font-['Work_Sans',sans-serif] text-[10px] font-semibold"> min</small></strong>
                  <span className="inline-flex items-center gap-[5px] whitespace-nowrap text-[9px] font-bold uppercase">{!shuttle.delayed && <i className="size-1.5 rounded-full bg-current" />}{shuttle.status}</span>
                </div>
                <button className={`col-span-2 flex min-h-[34px] w-full items-center justify-center gap-0.5 rounded px-2 text-[10px] font-semibold whitespace-nowrap md:col-span-1 md:px-1 md:text-[9px] lg:px-2 lg:text-[10px] ${index === 0 ? 'bg-[#126b91] text-white' : 'bg-[#f1f5f3] text-[#192b35]'}`} type="button">
                  {index === 0 ? 'Selected' : 'View stops'}<span className="material-symbols-outlined text-base">chevron_right</span>
                </button>
              </article>
            ))}
          </section>

          <aside className="flex flex-col gap-4 rounded-lg border border-[#dce4e5] bg-white p-3.5 sm:p-[17px] lg:sticky lg:top-[84px]" aria-label="Selected shuttle trip details">
            <div className="flex items-start justify-between gap-2.5">
              <div><span className="flex items-center gap-2 text-[9px] font-bold uppercase tracking-[.1em] text-[#126b91]"><i className="size-[7px] rounded-full bg-[#1c9a6d]" />Live trip track</span><h2 className="my-2 font-['Space_Grotesk',sans-serif] text-[17px] leading-tight font-semibold">Blue Express — Tech Park Loop</h2><p className="m-0 text-[10px] text-[#687780]">Vehicle #4092 · Double Decker · 82% seats free</p></div>
              <span className="material-symbols-outlined grid size-[38px] shrink-0 place-items-center rounded-md bg-[#edf3f2] text-[#126b91]">alt_route</span>
            </div>
            <div className="grid grid-cols-[1.15fr_.8fr_.8fr] items-center rounded-md bg-[#f1f5f3] px-1 py-[11px]">
              <div className="flex min-w-0 flex-col gap-[5px] border-r border-[#d5dfdc] px-[5px] sm:px-[7px]"><span className="text-[8px] text-[#687780] sm:text-[9px]">Boarding bay</span><strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold sm:text-xs">Platform 04</strong></div>
              <div className="flex min-w-0 flex-col gap-[5px] border-r border-[#d5dfdc] px-[5px] sm:px-[7px]"><span className="text-[8px] text-[#687780] sm:text-[9px]">Next in</span><strong className="whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold text-[#087a59] sm:text-xs">3 min</strong></div>
              <div className="flex min-w-0 flex-col gap-[5px] px-[5px] sm:px-[7px]"><span className="text-[8px] text-[#687780] sm:text-[9px]">Crowd level</span><strong className="flex items-center gap-1 whitespace-nowrap font-['Space_Grotesk',sans-serif] text-[10px] font-semibold text-[#087a59] sm:text-xs"><span className="material-symbols-outlined text-[15px]">groups</span>Low</strong></div>
            </div>
            <div>
              <h3 className="mb-[15px] text-[9px] font-bold uppercase tracking-[.08em] text-[#687780]">Sequential stop milestones</h3>
              <div className="relative flex flex-col gap-5 pl-[21px] before:absolute before:top-[9px] before:bottom-[10px] before:left-[6px] before:w-px before:bg-[#cbd7d6]">
                <div className="relative grid min-h-[38px] grid-cols-[minmax(0,1fr)_auto] items-center gap-1.5"><span className="material-symbols-outlined absolute top-px -left-[22px] z-[1] grid size-[15px] place-items-center rounded-full bg-[#087a59] text-[11px] text-white">check</span><div className="flex min-w-0 flex-col gap-1"><strong className="overflow-hidden text-[11px] font-semibold text-ellipsis whitespace-nowrap text-[#718087] line-through">Central Hub Depot</strong><small className="text-[9px] text-[#687780]">Departed at 14:35</small></div><em className="text-[9px] text-[#087a59] not-italic">Passed</em></div>
                <div className="relative -my-[5px] -ml-2 grid min-h-[38px] grid-cols-[minmax(0,1fr)_auto] items-center gap-1.5 rounded bg-[#edf5f6] px-2 py-[7px]"><span className="material-symbols-outlined absolute top-2 left-[-15px] z-[1] grid size-[15px] place-items-center rounded-full bg-[#126b91] text-[13px] text-white">sync</span><div className="flex min-w-0 flex-col gap-1"><strong className="overflow-hidden text-[11px] font-semibold text-ellipsis whitespace-nowrap text-[#126b91]">Bay 04 Concourse <b className="ml-1 rounded-[3px] bg-[#087a59] px-1 py-[3px] font-['Work_Sans',sans-serif] text-[8px] font-bold text-white uppercase">Current</b></strong><small className="text-[9px] text-[#687780]">Boarding doors opening</small></div><span className="flex flex-col items-end gap-1"><strong className="font-['Space_Grotesk',sans-serif] text-[11px] font-semibold text-[#126b91]">14:40</strong><small className="text-[9px] text-[#126b91]">ETA 3m</small></span></div>
                <div className="relative grid min-h-[38px] grid-cols-[minmax(0,1fr)_auto] items-center gap-1.5"><span className="material-symbols-outlined absolute top-px -left-[22px] z-[1] grid size-[15px] place-items-center rounded-full bg-white text-[13px] text-[#6e7c80]">circle</span><div className="flex min-w-0 flex-col gap-1"><strong className="overflow-hidden text-[11px] font-semibold text-ellipsis whitespace-nowrap">Medical Center North</strong><small className="text-[9px] text-[#687780]">Stop #14 · Gate B</small></div><span className="flex flex-col items-end gap-1"><strong className="font-['Space_Grotesk',sans-serif] text-[11px] font-semibold">14:52</strong><small className="text-[9px] text-[#687780]">ETA 12m</small></span></div>
                <div className="relative grid min-h-[38px] grid-cols-[minmax(0,1fr)_auto] items-center gap-1.5"><span className="material-symbols-outlined absolute top-px -left-[22px] z-[1] grid size-[15px] place-items-center rounded-full bg-white text-[13px] text-[#6e7c80]">flag</span><div className="flex min-w-0 flex-col gap-1"><strong className="overflow-hidden text-[11px] font-semibold text-ellipsis whitespace-nowrap">Tech Park Complex</strong><small className="text-[9px] text-[#687780]">Terminus · Innovation Hall</small></div><span className="flex flex-col items-end gap-1"><strong className="font-['Space_Grotesk',sans-serif] text-[11px] font-semibold">15:05</strong><small className="text-[9px] text-[#687780]">ETA 25m</small></span></div>
              </div>
            </div>
            <div className="flex flex-wrap justify-between gap-2 border-t border-[#e5ebea] pt-3 text-[9px] text-[#687780]"><span className="flex items-center gap-1"><span className="material-symbols-outlined text-[15px] text-[#126b91]">wifi</span>High-speed WiFi</span><span className="flex items-center gap-1"><span className="material-symbols-outlined text-[15px] text-[#126b91]">accessible</span>ADA ramp</span><span className="flex items-center gap-1"><span className="material-symbols-outlined text-[15px] text-[#126b91]">ac_unit</span>AC 70°</span></div>
            <button className="flex min-h-10 items-center justify-center gap-2 rounded bg-[#edf2f0] text-[11px] font-semibold" type="button"><span className="material-symbols-outlined text-[17px]">notifications</span>Receive arrival alert for Bay 04</button>
          </aside>
        </div>

        <section className="mt-[18px] flex flex-wrap items-start gap-3 rounded-md border border-[#dce7e2] bg-[#eaf1ed] p-3.5 sm:items-center">
          <span className="material-symbols-outlined grid size-[34px] shrink-0 place-items-center rounded-md bg-[#d9eaf0] text-[#126b91]">info</span>
          <div className="min-w-0 flex-1 basis-[calc(100%-50px)] sm:basis-0"><strong className="text-xs">Scheduled bay maintenance tonight</strong><p className="mt-1 mb-0 text-[11px] leading-relaxed text-[#687780]">Starting at 22:00, shuttles departing from Bay 01 and 02 will reroute through North Plaza Gate 8.</p></div>
          <a className="ml-[47px] whitespace-nowrap rounded bg-white px-3 py-2 text-[10px] font-semibold text-[#192b35] no-underline sm:ml-0" href="#maintenance">Learn more</a>
        </section>
      </main>

      <footer className="flex min-h-[60px] flex-wrap items-center gap-x-3 gap-y-2 border-t border-[#dce4e5] bg-white px-4 py-3 sm:px-6 xl:px-[max(24px,calc((100vw-1440px)/2))]"><strong className="font-['Space_Grotesk',sans-serif] text-base font-semibold text-[#126b91]">RouteBoard</strong><span className="text-[9px] text-[#687780] sm:text-[10px]">© 2025 Transit Operations Fleet Management</span><span className="flex w-full flex-wrap items-center gap-[7px] text-[9px] text-[#687780] sm:ml-auto sm:w-auto sm:text-[10px]"><i className="size-1.5 rounded-full bg-[#1c9a6d]" />Telemetry latency: 120ms <b className="text-[#a3adb0]">·</b> Transit Feed GTFS-RT v2.4</span></footer>
    </div>
  )
}
