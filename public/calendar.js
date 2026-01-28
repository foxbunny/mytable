import { $, renderList } from './common.js'

let fragmentPromise = fetch('_calendar.html')
	.then(r => r.text())
	.then(html => {
		let container = document.createElement('div')
		container.innerHTML = html
		for (let tmpl of container.querySelectorAll('template'))
			document.body.appendChild(tmpl)
	})

let calendarDayRecipe = {
	key: 'dateStr',
	day: (el, v) => el.textContent = v,
	dateStr: (el, v) => el.dataset.day = v,
	other: (el, v) => { if (v) el.dataset.other = ''; else delete el.dataset.other },
	today: (el, v) => { if (v) el.dataset.today = ''; else delete el.dataset.today },
	selected: (el, v) => { if (v) el.dataset.selected = ''; else delete el.dataset.selected },
	pending: (el, v) => { if (v) el.dataset.pending = ''; else delete el.dataset.pending },
}

let monthFmt = new Intl.DateTimeFormat(undefined, { month: 'long', year: 'numeric' })
let weekdayFmt = new Intl.DateTimeFormat(undefined, { weekday: 'short' })

let getWeekdayLabels = () => {
	let labels = []
	let base = new Date(2024, 0, 1) // A Monday
	for (let i = 0; i < 7; i++) {
		let d = new Date(base)
		d.setDate(base.getDate() + i)
		labels.push(weekdayFmt.format(d))
	}
	return labels
}

let toDateStr = d => d.toDateString()
let todayStr = () => new Date().toDateString()

export let initCalendar = (el, value) => {
	if (!el) return

	if (!el._calendarInit) {
		el._calendarInit = true
		let today = new Date()
		el._calendarSelected = toDateStr(today)
		el._calendarViewYear = today.getFullYear()
		el._calendarViewMonth = today.getMonth()
		el._calendarPending = new Set()

		fragmentPromise.then(() => {
			let calTpl = $('@calendar-widget')
			let calWidget = calTpl.content.cloneNode(true).firstElementChild
			el.appendChild(calWidget)
			el._calendarWidget = calWidget

			let weekdays = $('@weekdays', calWidget)
			getWeekdayLabels().forEach(label => {
				let span = document.createElement('span')
				span.textContent = label
				weekdays.appendChild(span)
			})

			// Use days container directly (remove slot placeholder)
			let daysContainer = $('@days', calWidget)
			daysContainer.innerHTML = ''
			el._calendarDaysContainer = daysContainer

			$('@prev', calWidget).addEventListener('click', () => navigate(el, -1))
			$('@next', calWidget).addEventListener('click', () => navigate(el, 1))
			$('@today', calWidget).addEventListener('click', () => goToday(el))
			daysContainer.addEventListener('click', ev => {
				let btn = ev.target.closest('button')
				if (btn) select(el, btn.dataset.day)
			})

			render(el)
		})
	}

	if (value !== undefined) {
		let d = value instanceof Date ? value : new Date(value)
		el._calendarSelected = toDateStr(d)
		el._calendarViewYear = d.getFullYear()
		el._calendarViewMonth = d.getMonth()
		if (el._calendarWidget) render(el)
	}
}

export let getCalendarValue = (el) => {
	if (!el || !el._calendarSelected) return null
	return new Date(el._calendarSelected)
}

export let setCalendarPending = (el, dates) => {
	if (!el) return

	el._calendarPending = new Set(
		(dates || []).map(d => toDateStr(new Date(d + 'T00:00:00')))
	)
	if (el._calendarWidget) render(el)
}

let navigate = (el, delta) => {
	el._calendarViewMonth += delta
	if (el._calendarViewMonth < 0) {
		el._calendarViewMonth = 11
		el._calendarViewYear--
	} else if (el._calendarViewMonth > 11) {
		el._calendarViewMonth = 0
		el._calendarViewYear++
	}
	render(el)
}

let goToday = el => {
	let today = new Date()
	el._calendarViewYear = today.getFullYear()
	el._calendarViewMonth = today.getMonth()
	select(el, toDateStr(today))
}

let select = (el, dateStr) => {
	el._calendarSelected = dateStr
	render(el)
	el.dispatchEvent(new CustomEvent('change', { detail: { value: new Date(dateStr) } }))
}

let render = el => {
	let calWidget = el._calendarWidget
	let today = todayStr()
	let year = el._calendarViewYear
	let month = el._calendarViewMonth
	let selected = el._calendarSelected
	let pending = el._calendarPending || new Set()

	let firstDay = new Date(year, month, 1)
	let lastDay = new Date(year, month + 1, 0)
	let startDay = (firstDay.getDay() + 6) % 7
	let daysInMonth = lastDay.getDate()
	let prevMonth = new Date(year, month, 0)
	let daysInPrev = prevMonth.getDate()

	let days = []
	for (let i = startDay - 1; i >= 0; i--) {
		let d = daysInPrev - i
		let date = new Date(year, month - 1, d)
		let dateStr = toDateStr(date)
		days.push({
			dateStr,
			day: d,
			other: true,
			today: dateStr == today,
			selected: dateStr == selected,
			pending: pending.has(dateStr),
		})
	}
	for (let d = 1; d <= daysInMonth; d++) {
		let date = new Date(year, month, d)
		let dateStr = toDateStr(date)
		days.push({
			dateStr,
			day: d,
			other: false,
			today: dateStr == today,
			selected: dateStr == selected,
			pending: pending.has(dateStr),
		})
	}
	let remaining = 42 - days.length
	for (let d = 1; d <= remaining; d++) {
		let date = new Date(year, month + 1, d)
		let dateStr = toDateStr(date)
		days.push({
			dateStr,
			day: d,
			other: true,
			today: dateStr == today,
			selected: dateStr == selected,
			pending: pending.has(dateStr),
		})
	}

	$('@month-year', calWidget).textContent = monthFmt.format(firstDay)
	renderList(el._calendarDaysContainer, days, 'calendar-day', calendarDayRecipe)
}
