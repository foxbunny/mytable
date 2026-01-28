import { api, $ } from './common.js'

let state = {
	formData: null,
	token: null,
	countdownTimer: null,
	countdownSeconds: 60,
	sse: null
}

let toastList = document.getElementById('toast-list')
let toastTpl = $('@toast-template')

let showToast = (message) => {
	let toast = toastTpl.content.cloneNode(true).firstElementChild
	$('@toast-message', toast).textContent = message
	$('@toast-dismiss', toast).addEventListener('click', () => {
		toast.dataset.clear = ''
		setTimeout(() => toast.remove(), 300)
	})
	toast.addEventListener('animationend', ev => {
		if (ev.animationName == 'expire') {
			toast.dataset.clear = ''
			setTimeout(() => toast.remove(), 300)
		}
	})
	toastList.appendChild(toast)
}

let flow = $('@flow')
let form = $('@reservation-form')
let resDate = $('@res-date')
let resTime = $('@res-time')
let countdownSeconds = $('@countdown-seconds')
let countdownFill = $('@countdown-fill')

let previewName = $('@preview-name')
let previewContact = $('@preview-contact')
let previewParty = $('@preview-party')
let previewDate = $('@preview-date')
let previewTime = $('@preview-time')
let previewNotesRow = $('@preview-notes-row')
let previewNotes = $('@preview-notes')

let waitingName = $('@waiting-name')
let waitingParty = $('@waiting-party')
let waitingDate = $('@waiting-date')
let waitingTime = $('@waiting-time')

let confirmedName = $('@confirmed-name')
let confirmedParty = $('@confirmed-party')
let confirmedDate = $('@confirmed-date')
let confirmedTime = $('@confirmed-time')
let confirmedMessage = $('@confirmed-message')
let confirmedMessageText = $('@confirmed-message-text')

let declinedMessage = $('@declined-message')
let declinedMessageText = $('@declined-message-text')

let copyLinkText = $('@copy-link-text')
let copyLinkDone = $('@copy-link-done')

let formatDate = d => {
	if (!d) return ''
	return new Date(d + 'T00:00:00').toLocaleDateString(undefined, {
		weekday: 'long',
		month: 'long',
		day: 'numeric'
	})
}

let formatTime = t => {
	if (!t) return ''
	let [h, m] = t.split(':')
	let hour = parseInt(h)
	let ampm = hour >= 12 ? 'PM' : 'AM'
	hour = hour % 12 || 12
	return `${hour}:${m} ${ampm}`
}

let setStep = (step) => flow.dataset.step = step

let setFormDefaults = () => {
	let now = new Date()
	let yyyy = now.getFullYear()
	let mm = String(now.getMonth() + 1).padStart(2, '0')
	let dd = String(now.getDate()).padStart(2, '0')
	let today = `${yyyy}-${mm}-${dd}`

	resDate.min = today
	resDate.value = today

	// Default time to 90 minutes from now, rounded to nearest 15 min
	let future = new Date(now.getTime() + 90 * 60 * 1000)
	let h = future.getHours()
	let m = Math.ceil(future.getMinutes() / 15) * 15
	if (m >= 60) { m = 0; h++ }
	if (h >= 24) { h = 0 }
	resTime.value = String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0')
}

let validateNotInPast = () => {
	let date = resDate.value
	let time = resTime.value
	if (!date || !time) return
	let selected = new Date(date + 'T' + time)
	let isPast = selected < new Date()
	resTime.setCustomValidity(isPast ? 'Reservation time cannot be in the past' : '')
}

let populatePreview = (data) => {
	previewName.textContent = data.guestName
	previewContact.textContent = data.guestPhone || data.guestEmail || '—'
	previewParty.textContent = data.partySize
	previewDate.textContent = formatDate(data.reservationDate)
	previewTime.textContent = formatTime(data.reservationTime)

	if (data.notes) previewNotes.textContent = data.notes
	previewNotesRow.hidden = !data.notes
}

let populateWaiting = (data) => {
	waitingName.textContent = data.guestName || data.guest_name
	waitingParty.textContent = data.partySize || data.party_size
	waitingDate.textContent = formatDate(data.reservationDate || data.reservation_date)
	waitingTime.textContent = formatTime(data.reservationTime || data.reservation_time)
}

let populateConfirmed = (data, message) => {
	confirmedName.textContent = data.guestName || data.guest_name
	confirmedParty.textContent = data.partySize || data.party_size
	confirmedDate.textContent = formatDate(data.reservationDate || data.reservation_date)
	confirmedTime.textContent = formatTime(data.reservationTime || data.reservation_time)

	if (message) confirmedMessageText.textContent = message
	confirmedMessage.hidden = !message
}

let startCountdown = () => {
	state.countdownSeconds = 60
	countdownSeconds.textContent = state.countdownSeconds
	countdownFill.style.setProperty('--progress', 100)

	state.countdownTimer = setInterval(() => {
		state.countdownSeconds--
		countdownSeconds.textContent = state.countdownSeconds
		countdownFill.style.setProperty('--progress', state.countdownSeconds / 60 * 100)

		if (state.countdownSeconds <= 0) {
			clearCountdown()
			submitReservation()
		}
	}, 1000)
}

let clearCountdown = () => {
	if (state.countdownTimer) {
		clearInterval(state.countdownTimer)
		state.countdownTimer = null
	}
}

let submitReservation = () => {
	let data = state.formData
	console.assert(data, 'No form data to submit')

	state.channelId = crypto.randomUUID()

	api.post('customer-create-reservation', {
		pGuestName: data.guestName,
		pPartySize: parseInt(data.partySize),
		pReservationDate: data.reservationDate,
		pReservationTime: data.reservationTime,
		pGuestPhone: data.guestPhone || null,
		pGuestEmail: data.guestEmail || null,
		pNotes: data.notes || null,
		pChannelId: state.channelId
	}).then(result => {
		if (result && result.sessionToken) {
			state.token = result.sessionToken
			// Update URL with token (bookmarkable)
			let url = new URL(location.href)
			url.searchParams.set('token', state.token)
			history.replaceState(null, '', url)
			// Store channel in sessionStorage (survives refresh)
			sessionStorage.setItem('channelId', state.channelId)

			populateWaiting(data)
			setStep('waiting')
			startSSE()
		}
	}).catch(() => showToast('Failed to submit reservation. Please try again.'))
}

let startSSE = () => {
	if (!state.token) return

	state.sse = new EventSource('/api/resolve-reservation/info')

	state.sse.onmessage = ev => {
		let data = JSON.parse(ev.data)
		if (data.channelId == state.channelId)
			handleNotification(data.code, data.adminMessage)
	}
}

let handleNotification = (code, message, data) => {
	if (state.sse) {
		state.sse.close()
		state.sse = null
	}

	// Mark as delivered
	if (state.token)
		api.post('mark-notification-delivered', { pToken: state.token })

	// Use state.formData or data from server
	let resData = state.formData || data || {}

	if (code == 'reservation_confirmed') {
		populateConfirmed(resData, message)
		setStep('confirmed')
	} else if (code == 'reservation_declined') {
		if (message) declinedMessageText.textContent = message
		declinedMessage.hidden = !message
		setStep('declined')
	}
}

let loadFromToken = (token) => {
	state.token = token

	api.get('get-customer-notification', { pToken: token }).then(data => {
		if (data) {
			// Build a data object for display
			let displayData = {
				guestName: data.guestName,
				partySize: data.partySize,
				reservationDate: data.reservationDate,
				reservationTime: data.reservationTime
			}

			if (data.reservationStatus == 'pending') {
				populateWaiting(displayData)
				setStep('waiting')
				startSSE()
			} else if (data.reservationStatus == 'confirmed') {
				populateConfirmed(displayData, data.adminMessage)
				setStep('confirmed')
			} else if (data.reservationStatus == 'declined') {
				if (data.adminMessage) declinedMessageText.textContent = data.adminMessage
				declinedMessage.hidden = !data.adminMessage
				setStep('declined')
			}
		} else {
			// No data (expired session), show form
			setStep('form')
		}
	}).catch(() => {
		// Invalid token, show form
		setStep('form')
	})
}

let resetForm = () => {
	state.formData = null
	state.token = null
	state.channelId = null
	sessionStorage.removeItem('channelId')
	// Clear token from URL
	let url = new URL(location.href)
	url.searchParams.delete('token')
	history.replaceState(null, '', url)
	// Reset form
	form.reset()
	setFormDefaults()
	validateNotInPast()
	setStep('form')
}

// Event handlers
resDate.addEventListener('change', validateNotInPast)
resTime.addEventListener('change', validateNotInPast)

form.addEventListener('submit', ev => {
	ev.preventDefault()
	let data = Object.fromEntries(new FormData(form))
	state.formData = data
	populatePreview(data)
	setStep('preview')
	startCountdown()
})

// Delegated action handler
flow.addEventListener('click', ev => {
	let btn = ev.target.closest('button[data-action]')
	if (!btn) return
	let action = btn.dataset.action

	if (action == 'edit') {
		clearCountdown()
		setStep('form')
	} else if (action == 'submit-now') {
		clearCountdown()
		submitReservation()
	} else if (action == 'retry') {
		resetForm()
	} else if (action == 'copy-link') {
		navigator.clipboard.writeText(location.href).then(() => {
			copyLinkText.hidden = true
			copyLinkDone.hidden = false
			setTimeout(() => {
				copyLinkText.hidden = false
				copyLinkDone.hidden = true
			}, 2000)
		})
	}
})

// Initialize
setFormDefaults()
validateNotInPast()

// Check for token in URL
let urlParams = new URLSearchParams(location.search)
let token = urlParams.get('token')
if (token) {
	state.channelId = sessionStorage.getItem('channelId')
	loadFromToken(token)
}
