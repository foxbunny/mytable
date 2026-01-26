import { api, part, makeChangeTogether, registerTemplate } from './common.js'
import './calendar.js'

// ── Recipes ──

registerTemplate('floor-tabs', {
	[registerTemplate.create]: ($) => {
		$.on('click', () => selectFloorplan(parseInt($.data('floorplanId'))))
	},
	name: ($, v) => $.text(v),
	floorplanId: ($, v) => $.data('floorplanId', v),
	active: ($, v) => $.data('active', v || false),
})

registerTemplate('table-markers', {
	[registerTemplate.create]: ($) => {
		$.on('click', ev => {
			ev.stopPropagation()
			let id = parseInt($.data('tableId'))
			if (state.bookingMode) {
				let table = state.bookingSlotTables.find(t => t.id == id)
				if (table) toggleBookingTable(table)
			} else {
				selectTable(id)
			}
		})
	},
	name: ($, v) => $.part('marker-name').text(v),
	x: ($, v) => $.cssProp('--x', v),
	y: ($, v) => $.cssProp('--y', v),
	tableId: ($, v) => $.data('tableId', v),
	blocked: ($, v) => $.data('blocked', v || false),
	occupied: ($, v) => $.data('occupied', v || false),
	selected: ($, v) => $.data('selected', v || false),
	unavailable: ($, v) => $.data('unavailable', v || false),
	bookingSelected: ($, v) => $.data('bookingSelected', v || false),
})

registerTemplate('reservation-list', {
	[registerTemplate.create]: ($) => {
		$.on('click', () => {
			let id = parseInt($.data('reservationId'))
			let res = state.reservations.find(r => r.id == id)
			if (!res) return
			if (res.status == 'pending') enterBookingMode('pending', res)
			else showDetailView(res)
		})
		$.on('mouseenter', () => {
			let id = parseInt($.data('reservationId'))
			let res = state.reservations.find(r => r.id == id)
			if (res) highlightTables(res.tableIds)
		})
		$.on('mouseleave', () => highlightTables(null))
	},
	time: ($, v) => $.part('res-item-time').text(v),
	endTime: ($, v) => $.part('res-item-end').text(v),
	guest: ($, v) => $.part('res-item-guest').text(v),
	party: ($, v) => $.part('res-item-party').text(v),
	status: ($, v) => $.part('res-item-status').text(v).data('status', v),
	reservationId: ($, v) => $.data('reservationId', v),
	urgent: ($, v) => $.data('urgent', v || false),
})

// ── State ──

let toDateStr = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
let fromDateStr = s => new Date(s + 'T00:00:00')

let state = {
	currentDate: new Date(),
	currentFloorplanId: null,
	floorplans: [],
	tableStatus: [],
	reservations: [],
	selectedTableId: null,
	viewingReservation: null,
	bookingMode: null,
	bookingPendingRes: null,
	bookingSlotTables: [],
	bookingSelectedIds: []
}

// ── Render content ──

let page = part('content').render()
part('content').replaceWith(page)

// ── Refs (content) ──

let $sidebar = page.part('sidebar')
let $calendar = page.part('calendar')
let $floorplanImage = page.part('floorplan-image')
let $tableMarkers = page.part('table-markers')
let $toolbarBlock = page.part('toolbar-block')

let $bookingParty = page.part('booking-party')
let $bookingDate = page.part('booking-date')
let $bookingTime = page.part('booking-time')
let $bookingDuration = page.part('booking-duration')
let $sidebarBooking = page.part('sidebar-booking')
let $bookingAdminMessage = page.part('booking-admin-message')

// ── Refs (dialogs & toasts — outside content template) ──

let $toastList = document.getElementById('toast-list')
let toastTpl = part('toast-template')
let newResToastTpl = part('new-res-toast-template')

let $reservationDialog = part('reservation-dialog')
let $dialogSubmit = part('dialog-submit')
let $reservationForm = part('reservation-form')
let $tableSelect = part('table-select')
let $dialogTableName = part('dialog-table-name')
let $formErrorText = part('form-error-text')

let $guestDialog = part('guest-dialog')
let $guestForm = part('guest-form')

// ── Shared utilities ──

let formatTime = t => t ? t.slice(0, 5) : ''
let formatDate = d => {
	if (!d) return ''
	return fromDateStr(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}
let addMinutes = (t, mins) => {
	let [h, m] = t.split(':').map(Number)
	m += mins
	h += Math.floor(m / 60)
	m %= 60
	return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0')
}
let formatDuration = mins => {
	if (mins < 60) return mins + ' min'
	let h = Math.floor(mins / 60)
	let m = mins % 60
	return m ? `${h}h ${m}m` : `${h}h`
}

let isUrgent = res => {
	if (res.status != 'pending' && res.status != 'confirmed') return false
	let now = new Date()
	if (toDateStr(state.currentDate) != toDateStr(now)) return false
	let [h, m] = res.reservationTime.split(':').map(Number)
	let resTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m)
	return resTime - now <= 15 * 60 * 1000
}

let isToday = (d) => {
	let today = new Date()
	return d.getFullYear() == today.getFullYear() &&
		d.getMonth() == today.getMonth() &&
		d.getDate() == today.getDate()
}

// Position table markers overlay to match rendered image bounds
let positionTableMarkers = () => {
	if (!$floorplanImage.get('naturalWidth')) return

	let imgRatio = $floorplanImage.get('naturalWidth') / $floorplanImage.get('naturalHeight')
	let boxW = $floorplanImage.get('clientWidth')
	let boxH = $floorplanImage.get('clientHeight')
	let boxRatio = boxW / boxH

	let renderW, renderH
	if (imgRatio > boxRatio) {
		renderW = boxW
		renderH = boxW / imgRatio
	} else {
		renderH = boxH
		renderW = boxH * imgRatio
	}

	$tableMarkers.cssProp('--x', (boxW - renderW) / 2)
	$tableMarkers.cssProp('--y', (boxH - renderH) / 2)
	$tableMarkers.cssProp('--w', renderW)
	$tableMarkers.cssProp('--h', renderH)
}

$floorplanImage.on('load', positionTableMarkers)
window.addEventListener('resize', positionTableMarkers)

// ── Toast ──

let showToast = (message, level = 'info') => {
	let toast = toastTpl.render()
	toast.part('toast-message').text(message)
	toast.data('level', level)

	toast.part('toast-dismiss').on('click', () => {
		toast.data('clear', '')
		setTimeout(() => toast.remove(), 300)
	})

	toast.on('animationend', ev => {
		if (ev.animationName == 'expire') {
			toast.data('clear', '')
			setTimeout(() => toast.remove(), 300)
		}
	})

	toast.each(el => $toastList.appendChild(el))
}

let showNewResToast = (r) => {
	let toast = newResToastTpl.render()
	toast.part('toast-guest').text(r.guestName)
	toast.part('toast-party').text(r.partySize)

	toast.part('toast-dismiss').on('click', () => {
		toast.data('clear', '')
		setTimeout(() => toast.remove(), 300)
	})

	toast.on('animationend', ev => {
		if (ev.animationName == 'expire') {
			toast.data('clear', '')
			setTimeout(() => toast.remove(), 300)
		}
	})

	toast.each(el => $toastList.appendChild(el))
}

// ── SSE ──

let startAdminSSE = () => {
	let sse = new EventSource('/api/customer-create-reservation/info')

	sse.onmessage = ev => {
		let data = JSON.parse(ev.data)
		if (data.code == 'new_pending') {
			showNewResToast(data)
			loadPendingDates()
		}
		loadDataForDate()
	}
}

// ── Calendar ──

let dateSync = makeChangeTogether()
	.bind($bookingDate, 'val', d => toDateStr(d))
	.bind($calendar, 'calendar')
	.bind(v => {
		state.currentDate = v
		if (state.bookingMode)
			loadSlotTables()
		else
			loadDataForDate().then(updateToolbar).catch(() => showToast('Failed to load data', 'error'))
	})
	.setFromEvent($calendar, 'change', { detail: 'value' })
	.setFromEvent($bookingDate, 'change', { val: true }, fromDateStr)

let bookingLock = makeChangeTogether()
	.bind($bookingParty, 'readOnly')
	.bind($bookingDate, 'readOnly')
	.bind($bookingTime, 'readOnly')
	.bind(v => $calendar.data('disabled', v ? '' : null))

// ── Floorplan ──

let loadFloorplans = () => {
	return api.get('get-floorplans').then(floorplans => {
		state.floorplans = floorplans
		if (floorplans.length > 0 && !state.currentFloorplanId)
			state.currentFloorplanId = floorplans[0].id
		renderFloorTabs()
		return floorplans
	})
}

let renderFloorTabs = () => {
	let empty = state.floorplans.length == 0
	page.part('floorplan-canvas').hidden(empty)
	page.part('no-floorplans').shown(empty)
	if (empty) {
		page.renderFromTemplate('floor-tabs', [])
		return
	}

	let items = state.floorplans.map(fp => ({
		id: fp.id,
		name: fp.name,
		floorplanId: fp.id,
		active: fp.id == state.currentFloorplanId,
	}))
	page.renderFromTemplate('floor-tabs', items)
}

let selectFloorplan = (id) => {
	state.currentFloorplanId = id
	renderFloorTabs()
	if (state.bookingMode)
		renderBookingFloorplan()
	else
		renderFloorplan()
}

let loadDataForDate = () => {
	return Promise.all([
		api.get('get-table-status-for-date', { pDate: toDateStr(state.currentDate) }),
		api.get('get-reservations-for-date', { pDate: toDateStr(state.currentDate) })
	]).then(([tableStatus, reservations]) => {
		state.tableStatus = tableStatus
		state.reservations = reservations
		renderFloorplan()
		renderReservationList()
	})
}

let renderFloorplan = () => {
	let fp = state.floorplans.find(f => f.id == state.currentFloorplanId)
	if (!fp) return

	$floorplanImage.src(fp.imagePath)

	let tables = state.tableStatus.filter(t => t.floorplanId == state.currentFloorplanId)
	let items = tables.map(t => ({
		id: t.id,
		name: t.name,
		x: t.xPct * 100,
		y: t.yPct * 100,
		tableId: t.id,
		blocked: t.isBlocked,
		occupied: !t.isBlocked && t.reservations.length > 0,
		selected: t.id == state.selectedTableId,
		unavailable: false,
		bookingSelected: false,
	}))
	page.renderFromTemplate('table-markers', items)
}

// ── Reservation List ──

let renderReservationList = () => {
	let empty = state.reservations.length == 0
	page.part('reservation-list').hidden(empty)
	page.part('no-reservations').shown(empty)

	let items = state.reservations.map(res => ({
		id: res.id,
		time: formatTime(res.reservationTime),
		endTime: addMinutes(res.reservationTime, res.durationMinutes),
		guest: res.guestName,
		party: res.partySize,
		status: res.status,
		reservationId: res.id,
		urgent: isUrgent(res),
	}))
	page.renderFromTemplate('reservation-list', items)
}

let highlightTables = (ids) => {
	for (let marker of $tableMarkers.get('children')) {
		if (ids?.includes(parseInt(marker.dataset.tableId)))
			marker.dataset.highlighted = ''
		else
			delete marker.dataset.highlighted
	}
}

// ── Detail View ──

let showDetailView = (res) => {
	state.viewingReservation = res
	$sidebar.data('mode', 'detail')
	page.part('sidebar-detail').data('status', res.status)

	page.part('detail-guest-name').text(res.guestName)
	page.part('detail-guest-contact').text(res.guestPhone || res.guestEmail || '—')

	page.part('detail-date').text(formatDate(res.reservationDate))
	page.part('detail-time').text(formatTime(res.reservationTime) + ' – ' + addMinutes(res.reservationTime, res.durationMinutes))
	page.part('detail-party').text(res.partySize)
	page.part('detail-duration').text(formatDuration(res.durationMinutes))
	page.part('detail-tables').text(res.tableNames?.length ? res.tableNames.join(', ') : '—')

	if (res.notes) page.part('detail-notes-text').text(res.notes)
	page.part('detail-notes').shown(!!res.notes)

	highlightTables(res.tableIds)
}

let exitDetailView = () => {
	state.viewingReservation = null
	$sidebar.data('mode', 'list')
	highlightTables(null)
}

let updateReservationStatus = (status) => {
	let res = state.viewingReservation
	if (!res) return

	api.post('update-reservation-status', { pId: res.id, pStatus: status }).then(() => {
		exitDetailView()
		loadDataForDate()
		loadPendingDates()
	}).catch(() => showToast('Failed to update reservation status', 'error'))
}

page.part('sidebar-detail').action({
	back: () => exitDetailView(),
	completed: () => updateReservationStatus('completed'),
	no_show: () => updateReservationStatus('no_show'),
	cancelled: () => updateReservationStatus('cancelled'),
})

// ── Table Selection ──

let selectTable = (id) => {
	state.selectedTableId = state.selectedTableId == id ? null : id
	updateToolbar()
	renderFloorplan()
}

let getSelectedTable = () => {
	return state.tableStatus.find(t => t.id == state.selectedTableId)
}

let updateToolbar = () => {
	let table = getSelectedTable()
	let today = isToday(state.currentDate)

	$toolbarBlock.shown(today)
	$toolbarBlock.disabled(!table)

	if (table)
		$toolbarBlock.data('blocked', table.isBlocked || false)
}

document.addEventListener('click', ev => {
	if (state.bookingMode) return
	if (!ev.target.closest('.table-marker') && !ev.target.closest('#floorplan-toolbar')) {
		state.selectedTableId = null
		updateToolbar()
		renderFloorplan()
	}
})

$toolbarBlock.on('click', () => {
	let table = getSelectedTable()
	if (!table) return
	let action = table.isBlocked ? 'unblock-table' : 'block-table'
	api.post(action, { pTableId: table.id }).then(() => {
		loadDataForDate().then(updateToolbar)
	}).catch(() => showToast('Failed to update table status', 'error'))
})

// ── Booking ──

page.part('new-res-btn').on('click', () => enterBookingMode('new'))

let loadPendingDates = () => {
	return api.get('get-pending-dates').then(dates => {
		$calendar.calendarPending(dates)
	})
}

let getDefaultDuration = (partySize) => {
	return Math.min(30 + partySize * 30, 300)
}

let getSuggestedTime = () => {
	let now = new Date()
	let h = now.getHours()
	let m = now.getMinutes()
	if (m < 30) m = 30
	else { m = 0; h++ }
	return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0')
}

let resetBookingUI = () => {
	$sidebarBooking.data('bookingMode', 'new')
	page.part('booking-guest-info').hidden()
	page.part('booking-guest-name').text('')
	page.part('booking-guest-contact').text('')
	$bookingParty.val(2)
	$bookingDate.val(toDateStr(state.currentDate))
	$bookingTime.val(getSuggestedTime())
	$bookingDuration.val(getDefaultDuration(2))
	page.part('booking-notes').hidden()
	page.part('booking-notes-text').text('')
	$bookingAdminMessage.val('')
	page.part('booking-decline').hidden()
	bookingLock.set(false)
}

let enterBookingMode = (mode, pendingRes = null) => {
	console.assert(mode == 'new' || mode == 'pending', 'Invalid booking mode')

	state.bookingMode = mode
	state.bookingPendingRes = pendingRes
	state.bookingSelectedIds = []

	$sidebar.data('mode', 'booking')
	page.part('floorplan-area').data('mode', 'booking')

	resetBookingUI()

	let preserveSelection = false

	if (mode == 'pending' && pendingRes) {
		$sidebarBooking.data('bookingMode', 'pending')
		page.part('booking-guest-info').shown()
		page.part('booking-guest-name').text(pendingRes.guestName)
		page.part('booking-guest-contact').text(pendingRes.guestPhone || pendingRes.guestEmail || '—')
		$bookingParty.val(pendingRes.partySize)
		$bookingDate.val(pendingRes.reservationDate)
		$bookingTime.val(pendingRes.reservationTime)
		$bookingDuration.val(pendingRes.durationMinutes)

		bookingLock.set(true)

		if (pendingRes.notes) {
			page.part('booking-notes-text').text(pendingRes.notes)
			page.part('booking-notes').shown()
		}

		page.part('booking-decline').shown()

		state.currentDate = fromDateStr(pendingRes.reservationDate)
		$calendar.calendar(state.currentDate)

		if (pendingRes.tableIds?.length) {
			state.bookingSelectedIds = [...pendingRes.tableIds]
			preserveSelection = true
		}
	}

	loadSlotTables(!preserveSelection)
}

let exitBookingMode = () => {
	state.bookingMode = null
	state.bookingPendingRes = null
	state.bookingSlotTables = []
	state.bookingSelectedIds = []

	bookingLock.set(false)

	$sidebar.data('mode', 'list')
	page.part('floorplan-area').data('mode', 'view')
	renderFloorplan()
}

let loadSlotTables = (clearSelection = true) => {
	let date = $bookingDate.val()
	let time = $bookingTime.val()
	let duration = parseInt($bookingDuration.val())
	let excludeId = state.bookingPendingRes?.id || null

	if (!date || !time) return

	if (clearSelection)
		state.bookingSelectedIds = []

	api.get('get-tables-for-slot', {
		pDate: date,
		pTime: time,
		pDuration: duration,
		pExcludeReservationId: excludeId
	}).then(tables => {
		state.bookingSlotTables = tables
		renderBookingFloorplan()
	}).catch(() => showToast('Failed to load table availability', 'error'))
}

let renderBookingFloorplan = () => {
	let fp = state.floorplans.find(f => f.id == state.currentFloorplanId)
	if (!fp) return

	$floorplanImage.src(fp.imagePath)

	let tables = state.bookingSlotTables.filter(t => t.floorplanId == state.currentFloorplanId)
	let items = tables.map(t => ({
		id: t.id,
		name: t.name,
		x: t.xPct * 100,
		y: t.yPct * 100,
		tableId: t.id,
		blocked: false,
		occupied: false,
		selected: false,
		unavailable: !t.isAvailable,
		bookingSelected: state.bookingSelectedIds.includes(t.id),
	}))
	page.renderFromTemplate('table-markers', items)

	updateBookingSelection()
}

let toggleBookingTable = (table) => {
	if (!table.isAvailable) return

	let idx = state.bookingSelectedIds.indexOf(table.id)
	if (idx >= 0)
		state.bookingSelectedIds.splice(idx, 1)
	else
		state.bookingSelectedIds.push(table.id)
	renderBookingFloorplan()
}

let updateBookingSelection = () => {
	let count = state.bookingSelectedIds.length
	let tables = state.bookingSlotTables.filter(t => state.bookingSelectedIds.includes(t.id))
	let totalCapacity = tables.reduce((sum, t) => sum + t.capacity, 0)
	let partySize = parseInt($bookingParty.val())

	let pct = partySize > 0 ? Math.min((totalCapacity / partySize) * 100, 100) : 0
	page.part('booking-capacity-fill').cssProp('--progress', pct)

	let bar = page.part('booking-capacity-fill').get('parentElement')
	delete bar.dataset.sufficient
	delete bar.dataset.over
	if (totalCapacity >= partySize && count > 0)
		bar.dataset.sufficient = ''
	if (totalCapacity > partySize)
		bar.dataset.over = ''

	page.part('booking-msg-empty').shown(count == 0)
	page.part('booking-msg-selected').shown(count > 0)
	if (count > 0) {
		page.part('booking-table-suffix').shown(count > 1)
		page.part('booking-table-names').text(tables.map(t => t.name).join(', '))
		page.part('booking-capacity-current').text(totalCapacity)
		page.part('booking-capacity-needed').text(partySize)
	}

	page.part('booking-confirm').disabled(count == 0)
}

let confirmBooking = () => {
	if (state.bookingSelectedIds.length == 0) return

	if (state.bookingMode == 'pending' && state.bookingPendingRes) {
		let res = state.bookingPendingRes
		let message = $bookingAdminMessage.val() || null

		// Update duration if changed
		let newDuration = parseInt($bookingDuration.val())
		let durationPromise = newDuration != res.durationMinutes
			? api.post('update-reservation', { pId: res.id, pDurationMinutes: newDuration })
			: Promise.resolve()

		durationPromise.then(() => {
			return api.post('resolve-reservation', {
				pId: res.id,
				pStatus: 'confirmed',
				pAdminMessage: message,
				pTableIds: state.bookingSelectedIds
			})
		}).then(() => {
			exitBookingMode()
			loadDataForDate()
			loadPendingDates()
		}).catch(() => showToast('Failed to confirm reservation', 'error'))
	} else {
		$guestForm.each(el => el.reset())
		$guestDialog.modal()
	}
}

let declineBooking = () => {
	if (!state.bookingPendingRes) return

	let message = $bookingAdminMessage.val() || null
	api.post('resolve-reservation', {
		pId: state.bookingPendingRes.id,
		pStatus: 'declined',
		pAdminMessage: message
	}).then(() => {
		exitBookingMode()
		loadDataForDate()
		loadPendingDates()
	}).catch(() => showToast('Failed to decline reservation', 'error'))
}

let createNewReservation = (guestData) => {
	let payload = {
		pGuestName: guestData.guestName,
		pGuestPhone: guestData.guestPhone || null,
		pGuestEmail: guestData.guestEmail || null,
		pPartySize: parseInt($bookingParty.val()),
		pReservationDate: $bookingDate.val(),
		pReservationTime: $bookingTime.val(),
		pDurationMinutes: parseInt($bookingDuration.val()),
		pTableIds: state.bookingSelectedIds,
		pSource: 'phone',
		pNotes: guestData.notes || null
	}

	api.post('create-reservation', payload).then(result => {
		if (!result.error) {
			$guestDialog.modal(false)
			exitBookingMode()
			loadDataForDate()
			loadPendingDates()
		}
	}).catch(() => showToast('Failed to create reservation', 'error'))
}

$sidebarBooking.action({
	back: () => exitBookingMode(),
	decline: () => declineBooking(),
	confirm: () => confirmBooking(),
	time: () => loadSlotTables(),
	duration: () => loadSlotTables(),
	party: () => {
		let partySize = parseInt($bookingParty.val())
		$bookingDuration.val(getDefaultDuration(partySize))
		loadSlotTables()
	},
})

$guestDialog.action({ close: () => $guestDialog.modal(false) })
$guestForm.submit(data => createNewReservation(data))

// ── Reservation Dialog ──

let openNewReservation = () => {
	state.editingReservationId = null
	$reservationDialog.data('mode', 'new')
	$reservationDialog.data('msg', false)
	$reservationForm.each(el => el.reset())
	part('res-date').val(toDateStr(state.currentDate))
	part('source-select').val('phone')
	loadTableOptions()
	$reservationDialog.modal()
}

let openNewReservationForTable = (table) => {
	state.editingReservationId = null
	$reservationDialog.data('mode', 'new-table')
	$reservationDialog.data('msg', false)
	$dialogTableName.text(table.name)
	$reservationForm.each(el => el.reset())
	part('res-date').val(toDateStr(state.currentDate))
	part('source-select').val('phone')
	loadTableOptions().then(() => {
		$tableSelect.val(table.id)
	})
	$reservationDialog.modal()
}

let openEditReservation = (res) => {
	state.editingReservationId = res.id
	$reservationDialog.data('mode', 'edit')
	$reservationDialog.data('msg', false)
	part('guest-name').val(res.guestName)
	part('guest-phone').val(res.guestPhone || '')
	part('guest-email').val(res.guestEmail || '')
	part('party-size').val(res.partySize)
	part('duration').val(res.durationMinutes)
	part('res-date').val(res.reservationDate)
	part('res-time').val(res.reservationTime)
	part('source-select').val(res.source)
	part('notes').val(res.notes || '')
	loadTableOptions().then(() => {
		$tableSelect.val(res.tableId || '')
	})
	$reservationDialog.modal()
}

let loadTableOptions = () => {
	return api.get('get-floorplans').then(floorplans => {
		$tableSelect.each(el => el.innerHTML = '<option value="">No table assigned</option>')

		return Promise.all(
			floorplans.map(fp =>
				api.get('get-floorplan-tables', { pFloorplanId: fp.id }).then(tables => ({ fp, tables }))
			)
		).then(results => {
			results.forEach(({ fp, tables }) => {
				if (tables.length == 0) return
				let group = document.createElement('optgroup')
				group.label = fp.name
				tables.forEach(t => {
					let opt = document.createElement('option')
					opt.value = t.id
					opt.textContent = `${t.name} (${t.capacity} seats)`
					group.appendChild(opt)
				})
				$tableSelect.append(group)
			})
		})
	})
}

$reservationDialog.action({ close: () => $reservationDialog.modal(false) })

$reservationForm.submit(data => {
	$reservationDialog.data('msg', false)

	let payload = {
		pGuestName: data.guestName,
		pGuestPhone: data.guestPhone || null,
		pGuestEmail: data.guestEmail || null,
		pPartySize: parseInt(data.partySize),
		pReservationDate: data.reservationDate,
		pReservationTime: data.reservationTime,
		pDurationMinutes: parseInt(data.durationMinutes),
		pTableId: data.tableId ? parseInt(data.tableId) : null,
		pSource: data.source,
		pNotes: data.notes || null
	}

	let action
	if (state.editingReservationId) {
		payload.pId = state.editingReservationId
		action = api.post('update-reservation', payload)
	} else {
		action = api.post('create-reservation', payload)
	}

	action.then(result => {
		if (result.error) {
			$formErrorText.text(result.error.split(': ')[1] || result.error)
			$reservationDialog.data('msg', 'api')
		} else {
			$reservationDialog.modal(false)
			loadDataForDate()
			loadPendingDates()
		}
	}).catch(() => {
		$reservationDialog.data('msg', 'network')
	})
})

// ── Init ──

dateSync.set(state.currentDate)

part('logout').on('click', () => {
	api.post('admin-logout').then(() => {
		window.location.href = 'login.html'
	})
})

api.get('get-restaurant').then(restaurant => {
	if (restaurant?.name) {
		document.title = `MyTable ${restaurant.name} Back Office`
		part('page-title').text(restaurant.name)
	}
})

startAdminSSE()

loadFloorplans()
	.then(() => loadDataForDate())
	.then(() => updateToolbar())
	.then(() => loadPendingDates())
	.catch(() => showToast('Failed to load data', 'error'))
