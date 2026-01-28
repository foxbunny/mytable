import { api, $, $$, renderList, showToast, delegate } from './common.js'
import { initCalendar, getCalendarValue, setCalendarPending } from './calendar.js'

// ── Recipes ──

let floorTabsRecipe = {
	create: (el) => {
		el.addEventListener('click', () => selectFloorplan(parseInt(el.dataset.floorplanId)))
	},
	name: (el, v) => el.textContent = v,
	floorplanId: (el, v) => el.dataset.floorplanId = v,
	active: (el, v) => el.toggleAttribute('data-active', v),
}

let tableMarkersRecipe = {
	create: (el) => {
		el.addEventListener('click', ev => {
			ev.stopPropagation()
			let id = parseInt(el.dataset.tableId)
			if (state.bookingMode) {
				let table = state.bookingSlotTables.find(t => t.id == id)
				if (table) toggleBookingTable(table)
			} else {
				selectTable(id)
			}
		})
	},
	name: (el, v) => $('@marker-name', el).textContent = v,
	x: (el, v) => el.style.setProperty('--x', v),
	y: (el, v) => el.style.setProperty('--y', v),
	tableId: (el, v) => el.dataset.tableId = v,
	blocked: (el, v) => el.toggleAttribute('data-blocked', v),
	occupied: (el, v) => el.toggleAttribute('data-occupied', v),
	selected: (el, v) => el.toggleAttribute('data-selected', v),
	unavailable: (el, v) => el.toggleAttribute('data-unavailable', v),
	bookingSelected: (el, v) => el.toggleAttribute('data-bookingSelected', v),
}

let reservationListRecipe = {
	create: (el) => {
		el.addEventListener('click', () => {
			let id = parseInt(el.dataset.reservationId)
			let res = state.reservations.find(r => r.id == id)
			if (!res) return
			if (res.status == 'pending') enterBookingMode('pending', res)
			else showDetailView(res)
		})
		el.addEventListener('mouseenter', () => {
			let id = parseInt(el.dataset.reservationId)
			let res = state.reservations.find(r => r.id == id)
			if (res) highlightTables(res.tableIds)
		})
		el.addEventListener('mouseleave', () => highlightTables(null))
	},
	time: (el, v) => $('@res-item-time', el).textContent = v,
	endTime: (el, v) => $('@res-item-end', el).textContent = v,
	guest: (el, v) => $('@res-item-guest', el).textContent = v,
	party: (el, v) => $('@res-item-party', el).textContent = v,
	status: (el, v) => { let s = $('@res-item-status', el); s.textContent = v; s.dataset.status = v },
	reservationId: (el, v) => el.dataset.reservationId = v,
	urgent: (el, v) => el.toggleAttribute('data-urgent', v),
}

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

let contentTpl = $('@content')
let page = contentTpl.content.cloneNode(true).firstElementChild
contentTpl.replaceWith(page)

// ── Refs (content) ──

let sidebar = $('@sidebar', page)
let calendar = $('@calendar', page)
let floorplanImage = $('@floorplan-image', page)
let tableMarkersContainer = $('@table-markers', page)
let toolbarBlock = $('@toolbar-block', page)

let bookingParty = $('@booking-party', page)
let bookingDate = $('@booking-date', page)
let bookingTime = $('@booking-time', page)
let bookingDuration = $('@booking-duration', page)
let sidebarBooking = $('@sidebar-booking', page)
let bookingAdminMessage = $('@booking-admin-message', page)

// Replace slot elements with containers for renderList
let floorTabsSlot = page.querySelector('slot[name="floor-tabs"]')
let floorTabsContainer = document.createElement('div')
floorTabsContainer.className = 'floor-tabs-container'
floorTabsSlot.replaceWith(floorTabsContainer)

let tableMarkersSlot = tableMarkersContainer.querySelector('slot[name="table-markers"]')
let tableMarkersListContainer = document.createElement('div')
tableMarkersListContainer.className = 'table-markers-list'
if (tableMarkersSlot) tableMarkersSlot.replaceWith(tableMarkersListContainer)

let reservationListContainer = $('@reservation-list', page)
reservationListContainer.innerHTML = ''

// ── Refs (dialogs & toasts — outside content template) ──

let toastList = document.getElementById('toast-list')
let newResToastTpl = $('@new-res-toast-template')

let reservationDialog = $('@reservation-dialog')
let dialogSubmit = $('@dialog-submit')
let reservationForm = $('@reservation-form')
let tableSelect = $('@table-select')
let dialogTableName = $('@dialog-table-name')
let formErrorText = $('@form-error-text')

let guestDialog = $('@guest-dialog')
let guestForm = $('@guest-form')

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

let isInPast = (date, time) => {
	if (!date || !time) return false
	return new Date(date + 'T' + time) < new Date()
}

// Position table markers overlay to match rendered image bounds
let positionTableMarkers = () => {
	if (!floorplanImage.naturalWidth) return

	let imgRatio = floorplanImage.naturalWidth / floorplanImage.naturalHeight
	let boxW = floorplanImage.clientWidth
	let boxH = floorplanImage.clientHeight
	let boxRatio = boxW / boxH

	let renderW, renderH
	if (imgRatio > boxRatio) {
		renderW = boxW
		renderH = boxW / imgRatio
	} else {
		renderH = boxH
		renderW = boxH * imgRatio
	}

	tableMarkersContainer.style.setProperty('--x', (boxW - renderW) / 2)
	tableMarkersContainer.style.setProperty('--y', (boxH - renderH) / 2)
	tableMarkersContainer.style.setProperty('--w', renderW)
	tableMarkersContainer.style.setProperty('--h', renderH)
}

floorplanImage.addEventListener('load', positionTableMarkers)
window.addEventListener('resize', positionTableMarkers)

// ── Toast ──

let dismissToast = (toast) => {
	toast.dataset.clear = ''
	setTimeout(() => toast.remove(), 300)
}

let showNewResToast = (r) => {
	let toast = newResToastTpl.content.cloneNode(true).firstElementChild
	$('@toast-guest', toast).textContent = r.guestName
	$('@toast-party', toast).textContent = r.partySize

	$('@toast-dismiss', toast).addEventListener('click', () => dismissToast(toast))
	toast.addEventListener('animationend', ev => {
		if (ev.animationName == 'expire') dismissToast(toast)
	})

	toastList.appendChild(toast)
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

// ── Date Sync (replaces makeChangeTogether) ──

let syncDateFromCalendar = (value) => {
	state.currentDate = value
	bookingDate.value = toDateStr(value)
	if (state.bookingMode)
		loadSlotTables()
	else
		loadDataForDate().then(updateToolbar).catch(() => showToast('Failed to load data', 'error'))
}

let syncDateFromInput = () => {
	let value = fromDateStr(bookingDate.value)
	state.currentDate = value
	initCalendar(calendar, value)
	if (state.bookingMode)
		loadSlotTables()
	else
		loadDataForDate().then(updateToolbar).catch(() => showToast('Failed to load data', 'error'))
}

let setDate = (value) => {
	state.currentDate = value
	bookingDate.value = toDateStr(value)
	initCalendar(calendar, value)
}

// ── Booking Lock (replaces makeChangeTogether) ──

let setBookingLock = (locked) => {
	bookingParty.readOnly = locked
	bookingDate.readOnly = locked
	bookingTime.readOnly = locked
	calendar.toggleAttribute('data-disabled', locked)
}

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
	$('@floorplan-canvas', page).hidden = empty
	$('@no-floorplans', page).hidden = !empty
	if (empty) {
		renderList(floorTabsContainer, [], 'floor-tabs', floorTabsRecipe)
		return
	}

	let items = state.floorplans.map(fp => ({
		id: fp.id,
		name: fp.name,
		floorplanId: fp.id,
		active: fp.id == state.currentFloorplanId,
	}))
	renderList(floorTabsContainer, items, 'floor-tabs', floorTabsRecipe)
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

	floorplanImage.src = fp.imagePath

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
	renderList(tableMarkersListContainer, items, 'table-markers', tableMarkersRecipe)
}

// ── Reservation List ──

let renderReservationList = () => {
	let empty = state.reservations.length == 0
	$('@reservation-list', page).hidden = empty
	$('@no-reservations', page).hidden = !empty

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
	renderList(reservationListContainer, items, 'reservation-list', reservationListRecipe)
}

let highlightTables = (ids) => {
	for (let marker of tableMarkersListContainer.children) {
		if (ids?.includes(parseInt(marker.dataset.tableId)))
			marker.dataset.highlighted = ''
		else
			delete marker.dataset.highlighted
	}
}

// ── Detail View ──

let showDetailView = (res) => {
	state.viewingReservation = res
	sidebar.dataset.mode = 'detail'
	$('@sidebar-detail', page).dataset.status = res.status

	$('@detail-guest-name', page).textContent = res.guestName
	$('@detail-guest-contact', page).textContent = res.guestPhone || res.guestEmail || '—'

	$('@detail-date', page).textContent = formatDate(res.reservationDate)
	$('@detail-time', page).textContent = formatTime(res.reservationTime) + ' – ' + addMinutes(res.reservationTime, res.durationMinutes)
	$('@detail-party', page).textContent = res.partySize
	$('@detail-duration', page).textContent = formatDuration(res.durationMinutes)
	$('@detail-tables', page).textContent = res.tableNames?.length ? res.tableNames.join(', ') : '—'

	let detailNotes = $('@detail-notes', page)
	if (res.notes) $('@detail-notes-text', page).textContent = res.notes
	detailNotes.hidden = !res.notes

	highlightTables(res.tableIds)
}

let exitDetailView = () => {
	state.viewingReservation = null
	sidebar.dataset.mode = 'list'
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

// Delegated action handler for sidebar-detail
$('@sidebar-detail', page).addEventListener('click', delegate('[data-action]', (ev, btn) => {
	let action = btn.dataset.action
	if (action == 'back') exitDetailView()
	else if (action == 'completed') updateReservationStatus('completed')
	else if (action == 'no_show') updateReservationStatus('no_show')
	else if (action == 'cancelled') updateReservationStatus('cancelled')
}))

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

	toolbarBlock.hidden = !today
	toolbarBlock.disabled = !table

	if (table) toolbarBlock.toggleAttribute('data-blocked', table.isBlocked)
}

document.addEventListener('click', ev => {
	if (state.bookingMode) return
	if (!ev.target.closest('.table-marker') && !ev.target.closest('#floorplan-toolbar')) {
		state.selectedTableId = null
		updateToolbar()
		renderFloorplan()
	}
})

toolbarBlock.addEventListener('click', () => {
	let table = getSelectedTable()
	if (!table) return
	let action = table.isBlocked ? 'unblock-table' : 'block-table'
	api.post(action, { pTableId: table.id }).then(() => {
		loadDataForDate().then(updateToolbar)
	}).catch(() => showToast('Failed to update table status', 'error'))
})

// ── Booking ──

$('@new-res-btn', page).addEventListener('click', () => enterBookingMode('new'))

let loadPendingDates = () => {
	return api.get('get-pending-dates').then(dates => {
		setCalendarPending(calendar, dates)
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
	sidebarBooking.dataset.bookingMode = 'new'
	$('@booking-guest-info', page).hidden = true
	$('@booking-guest-name', page).textContent = ''
	$('@booking-guest-contact', page).textContent = ''
	bookingParty.value = 2
	bookingDate.value = toDateStr(state.currentDate)
	bookingTime.value = getSuggestedTime()
	bookingDuration.value = getDefaultDuration(2)
	$('@booking-notes', page).hidden = true
	$('@booking-notes-text', page).textContent = ''
	bookingAdminMessage.value = ''
	$('@booking-decline', page).hidden = true
	setBookingLock(false)
}

let enterBookingMode = (mode, pendingRes = null) => {
	console.assert(mode == 'new' || mode == 'pending', 'Invalid booking mode')

	state.bookingMode = mode
	state.bookingPendingRes = pendingRes
	state.bookingSelectedIds = []

	sidebar.dataset.mode = 'booking'
	$('@floorplan-area', page).dataset.mode = 'booking'

	resetBookingUI()

	let preserveSelection = false

	if (mode == 'pending' && pendingRes) {
		sidebarBooking.dataset.bookingMode = 'pending'
		$('@booking-guest-info', page).hidden = false
		$('@booking-guest-name', page).textContent = pendingRes.guestName
		$('@booking-guest-contact', page).textContent = pendingRes.guestPhone || pendingRes.guestEmail || '—'
		bookingParty.value = pendingRes.partySize
		bookingDate.value = pendingRes.reservationDate
		bookingTime.value = pendingRes.reservationTime
		bookingDuration.value = pendingRes.durationMinutes

		setBookingLock(true)

		if (pendingRes.notes) {
			$('@booking-notes-text', page).textContent = pendingRes.notes
			$('@booking-notes', page).hidden = false
		}

		$('@booking-decline', page).hidden = false

		state.currentDate = fromDateStr(pendingRes.reservationDate)
		initCalendar(calendar, state.currentDate)

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

	setBookingLock(false)

	sidebar.dataset.mode = 'list'
	$('@floorplan-area', page).dataset.mode = 'view'
	renderFloorplan()
}

let loadSlotTables = (clearSelection = true) => {
	let date = bookingDate.value
	let time = bookingTime.value
	let duration = parseInt(bookingDuration.value)
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

	floorplanImage.src = fp.imagePath

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
	renderList(tableMarkersListContainer, items, 'table-markers', tableMarkersRecipe)

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
	let partySize = parseInt(bookingParty.value)

	let pct = partySize > 0 ? Math.min((totalCapacity / partySize) * 100, 100) : 0
	$('@booking-capacity-fill', page).style.setProperty('--progress', pct)

	let bar = $('@booking-capacity-fill', page).parentElement
	delete bar.dataset.sufficient
	delete bar.dataset.over
	if (totalCapacity >= partySize && count > 0)
		bar.dataset.sufficient = ''
	if (totalCapacity > partySize)
		bar.dataset.over = ''

	$('@booking-msg-empty', page).hidden = count != 0
	$('@booking-msg-selected', page).hidden = count == 0
	if (count > 0) {
		$('@booking-table-suffix', page).hidden = count <= 1
		$('@booking-table-names', page).textContent = tables.map(t => t.name).join(', ')
		$('@booking-capacity-current', page).textContent = totalCapacity
		$('@booking-capacity-needed', page).textContent = partySize
	}

	$('@booking-confirm', page).disabled = count == 0
}

let confirmBooking = () => {
	if (state.bookingSelectedIds.length == 0) return

	if (isInPast(bookingDate.value, bookingTime.value)) {
		showToast('Cannot create reservation in the past', 'error')
		return
	}

	if (state.bookingMode == 'pending' && state.bookingPendingRes) {
		let res = state.bookingPendingRes
		let message = bookingAdminMessage.value || null

		// Update duration if changed
		let newDuration = parseInt(bookingDuration.value)
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
		guestForm.reset()
		guestDialog.showModal()
	}
}

let declineBooking = () => {
	if (!state.bookingPendingRes) return

	let message = bookingAdminMessage.value || null
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
		pPartySize: parseInt(bookingParty.value),
		pReservationDate: bookingDate.value,
		pReservationTime: bookingTime.value,
		pDurationMinutes: parseInt(bookingDuration.value),
		pTableIds: state.bookingSelectedIds,
		pSource: 'phone',
		pNotes: guestData.notes || null
	}

	api.post('create-reservation', payload).then(result => {
		if (!result.error) {
			guestDialog.close()
			exitBookingMode()
			loadDataForDate()
			loadPendingDates()
		}
	}).catch(() => showToast('Failed to create reservation', 'error'))
}

// Delegated action handler for sidebar-booking
sidebarBooking.addEventListener('click', delegate('[data-action]', (ev, btn) => {
	let action = btn.dataset.action
	if (action == 'back') exitBookingMode()
	else if (action == 'decline') declineBooking()
	else if (action == 'confirm') confirmBooking()
}))

// Handle input/change events for booking params
sidebarBooking.addEventListener('change', ev => {
	let target = ev.target
	let action = target.dataset.action

	if (action == 'time' || action == 'duration') loadSlotTables()
	else if (action == 'party') {
		let partySize = parseInt(bookingParty.value)
		bookingDuration.value = getDefaultDuration(partySize)
		loadSlotTables()
	}
})

// Guest dialog actions
guestDialog.addEventListener('click', delegate('[data-action="close"]', () => guestDialog.close()))

guestForm.addEventListener('submit', ev => {
	ev.preventDefault()
	let data = Object.fromEntries(new FormData(guestForm))
	createNewReservation(data)
})

// ── Reservation Dialog ──

let openNewReservation = () => {
	state.editingReservationId = null
	reservationDialog.dataset.mode = 'new'
	delete reservationDialog.dataset.msg
	reservationForm.reset()
	$('@res-date').value = toDateStr(state.currentDate)
	$('@source-select').value = 'phone'
	loadTableOptions()
	reservationDialog.showModal()
}

let openNewReservationForTable = (table) => {
	state.editingReservationId = null
	reservationDialog.dataset.mode = 'new-table'
	delete reservationDialog.dataset.msg
	dialogTableName.textContent = table.name
	reservationForm.reset()
	$('@res-date').value = toDateStr(state.currentDate)
	$('@source-select').value = 'phone'
	loadTableOptions().then(() => {
		tableSelect.value = table.id
	})
	reservationDialog.showModal()
}

let openEditReservation = (res) => {
	state.editingReservationId = res.id
	reservationDialog.dataset.mode = 'edit'
	delete reservationDialog.dataset.msg
	$('@guest-name').value = res.guestName
	$('@guest-phone').value = res.guestPhone || ''
	$('@guest-email').value = res.guestEmail || ''
	$('@party-size').value = res.partySize
	$('@duration').value = res.durationMinutes
	$('@res-date').value = res.reservationDate
	$('@res-time').value = res.reservationTime
	$('@source-select').value = res.source
	$('@notes').value = res.notes || ''
	loadTableOptions().then(() => {
		tableSelect.value = res.tableId || ''
	})
	reservationDialog.showModal()
}

let loadTableOptions = () => {
	return api.get('get-floorplans').then(floorplans => {
		tableSelect.innerHTML = '<option value="">No table assigned</option>'

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
				tableSelect.appendChild(group)
			})
		})
	})
}

reservationDialog.addEventListener('click', delegate('[data-action="close"]', () => reservationDialog.close()))

reservationForm.addEventListener('submit', ev => {
	ev.preventDefault()
	let data = Object.fromEntries(new FormData(reservationForm))

	delete reservationDialog.dataset.msg

	if (isInPast(data.reservationDate, data.reservationTime)) {
		formErrorText.textContent = 'Cannot create reservation in the past'
		reservationDialog.dataset.msg = 'api'
		return
	}

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
			formErrorText.textContent = result.error.split(': ')[1] || result.error
			reservationDialog.dataset.msg = 'api'
		} else {
			reservationDialog.close()
			loadDataForDate()
			loadPendingDates()
		}
	}).catch(() => {
		reservationDialog.dataset.msg = 'network'
	})
})

// ── Init ──

// Initialize calendar
initCalendar(calendar, state.currentDate)

// Set up calendar change listener
calendar.addEventListener('change', ev => {
	syncDateFromCalendar(ev.detail.value)
})

// Set up booking date change listener
bookingDate.addEventListener('change', syncDateFromInput)

$('@logout').addEventListener('click', () => {
	api.post('admin-logout').then(() => {
		window.location.href = 'login.html'
	})
})

api.get('get-restaurant').then(restaurant => {
	if (restaurant?.name) {
		document.title = `MyTable ${restaurant.name} Back Office`
		$('@page-title').textContent = restaurant.name
	}
})

startAdminSSE()

loadFloorplans()
	.then(() => loadDataForDate())
	.then(() => updateToolbar())
	.then(() => loadPendingDates())
	.catch(() => showToast('Failed to load data', 'error'))
