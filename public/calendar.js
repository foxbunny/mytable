import { extend, part, registerTemplate } from './common.js'

let fragment = fetch('_calendar.html')
	.then(r => r.text())
	.then(html => {
		let container = document.createElement('div')
		container.innerHTML = html
		for (let tmpl of container.querySelectorAll('template'))
			document.body.appendChild(tmpl)
	})

registerTemplate('calendar-day', {
	[registerTemplate.key]: 'dateStr',
	day: ($, v) => $.text(v),
	dateStr: ($, v) => $.data('day', v),
	other: ($, v) => $.data('other', v ? '' : null),
	today: ($, v) => $.data('today', v ? '' : null),
	selected: ($, v) => $.data('selected', v ? '' : null),
	pending: ($, v) => $.data('pending', v ? '' : null),
})

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

extend('calendar', function (els, value) {
	let el = els[0]
	if (!el) return this

	if (arguments.length == 1)
		return new Date(el._calendarSelected)

	if (!el._calendarInit) {
		el._calendarInit = true
		let today = new Date()
		el._calendarSelected = toDateStr(today)
		el._calendarViewYear = today.getFullYear()
		el._calendarViewMonth = today.getMonth()
		el._calendarPending = new Set()

		fragment.then(() => {
			let calParts = part('calendar-widget').render()
			calParts.each(node => el.appendChild(node))
			el._calendarParts = calParts

			let weekdays = calParts.part('weekdays')
			getWeekdayLabels().forEach(label => {
				let span = document.createElement('span')
				span.textContent = label
				weekdays.append(span)
			})

			calParts.part('prev').on('click', () => navigate(el, -1))
			calParts.part('next').on('click', () => navigate(el, 1))
			calParts.part('today').on('click', () => goToday(el))
			calParts.part('days').on('click', ev => {
				let btn = ev.target.closest('button')
				if (btn) select(el, btn.dataset.day)
			})

			render(el)
		})
	}

	let d = value instanceof Date ? value : new Date(value)
	el._calendarSelected = toDateStr(d)
	el._calendarViewYear = d.getFullYear()
	el._calendarViewMonth = d.getMonth()
	if (el._calendarParts) render(el)

	return this
})

extend('calendarPending', function (els, dates) {
	let el = els[0]
	if (!el) return this

	el._calendarPending = new Set(
		(dates || []).map(d => toDateStr(new Date(d + 'T00:00:00')))
	)
	if (el._calendarParts) render(el)

	return this
})

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
	let calParts = el._calendarParts
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

	calParts.part('month-year').text(monthFmt.format(firstDay))
	calParts.renderFromTemplate('calendar-day', days)
}
