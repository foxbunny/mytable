import { api, part } from './common.js'

let state = {
	formData: null,
	token: null,
	countdownTimer: null,
	countdownSeconds: 60,
	sse: null,
	pollTimer: null
}

let $toastList = document.getElementById('toast-list')
let toastTpl = part('toast-template')

let showToast = (message) => {
	let toast = toastTpl.render()
	toast.part('toast-message').text(message)
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

let $flow = part('flow')
let $form = part('reservation-form')
let $countdownSeconds = part('countdown-seconds')
let $countdownFill = part('countdown-fill')

let $previewName = part('preview-name')
let $previewContact = part('preview-contact')
let $previewParty = part('preview-party')
let $previewDate = part('preview-date')
let $previewTime = part('preview-time')
let $previewNotesRow = part('preview-notes-row')
let $previewNotes = part('preview-notes')

let $waitingName = part('waiting-name')
let $waitingParty = part('waiting-party')
let $waitingDate = part('waiting-date')
let $waitingTime = part('waiting-time')

let $confirmedName = part('confirmed-name')
let $confirmedParty = part('confirmed-party')
let $confirmedDate = part('confirmed-date')
let $confirmedTime = part('confirmed-time')
let $confirmedMessage = part('confirmed-message')
let $confirmedMessageText = part('confirmed-message-text')

let $declinedMessage = part('declined-message')
let $declinedMessageText = part('declined-message-text')

let $copyLinkText = part('copy-link-text')
let $copyLinkDone = part('copy-link-done')

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

let setStep = (step) => $flow.data('step', step)

let setFormDefaults = () => {
	let now = new Date()
	let yyyy = now.getFullYear()
	let mm = String(now.getMonth() + 1).padStart(2, '0')
	let dd = String(now.getDate()).padStart(2, '0')
	let today = `${yyyy}-${mm}-${dd}`

	part('res-date').each(el => el.min = today)
	part('res-date').val(today)

	// Default time to 90 minutes from now, rounded to nearest 15 min
	let future = new Date(now.getTime() + 90 * 60 * 1000)
	let h = future.getHours()
	let m = Math.ceil(future.getMinutes() / 15) * 15
	if (m >= 60) { m = 0; h++ }
	if (h >= 24) { h = 0 }
	part('res-time').val(String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0'))
}

let populatePreview = (data) => {
	$previewName.text(data.guestName)
	$previewContact.text(data.guestPhone || data.guestEmail || '—')
	$previewParty.text(data.partySize)
	$previewDate.text(formatDate(data.reservationDate))
	$previewTime.text(formatTime(data.reservationTime))

	if (data.notes) $previewNotes.text(data.notes)
	$previewNotesRow.shown(!!data.notes)
}

let populateWaiting = (data) => {
	$waitingName.text(data.guestName || data.guest_name)
	$waitingParty.text(data.partySize || data.party_size)
	$waitingDate.text(formatDate(data.reservationDate || data.reservation_date))
	$waitingTime.text(formatTime(data.reservationTime || data.reservation_time))
}

let populateConfirmed = (data, message) => {
	$confirmedName.text(data.guestName || data.guest_name)
	$confirmedParty.text(data.partySize || data.party_size)
	$confirmedDate.text(formatDate(data.reservationDate || data.reservation_date))
	$confirmedTime.text(formatTime(data.reservationTime || data.reservation_time))

	if (message) $confirmedMessageText.text(message)
	$confirmedMessage.shown(!!message)
}

let startCountdown = () => {
	state.countdownSeconds = 60
	$countdownSeconds.text(state.countdownSeconds)
	$countdownFill.cssProp('--progress', 100)

	state.countdownTimer = setInterval(() => {
		state.countdownSeconds--
		$countdownSeconds.text(state.countdownSeconds)
		$countdownFill.cssProp('--progress', state.countdownSeconds / 60 * 100)

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

	api.post('customer-create-reservation', {
		pGuestName: data.guestName,
		pPartySize: parseInt(data.partySize),
		pReservationDate: data.reservationDate,
		pReservationTime: data.reservationTime,
		pGuestPhone: data.guestPhone || null,
		pGuestEmail: data.guestEmail || null,
		pNotes: data.notes || null
	}).then(result => {
		if (result && result.length > 0) {
			state.token = result[0].sessionToken
			// Update URL with token (bookmarkable)
			let url = new URL(location.href)
			url.searchParams.set('token', state.token)
			history.replaceState(null, '', url)

			populateWaiting(data)
			setStep('waiting')
			startSSE()
		}
	}).catch(() => showToast('Failed to submit reservation. Please try again.'))
}

let startSSE = () => {
	if (!state.token) return

	state.sse = new EventSource('/api/stream-customer-notifications?pToken=' + encodeURIComponent(state.token))

	state.sse.onmessage = ev => {
		let data = JSON.parse(ev.data)
		handleNotification(data.code, data.adminMessage)
	}

	state.sse.onerror = () => {
		// Fall back to polling
		state.sse.close()
		state.sse = null
		startPolling()
	}
}

let startPolling = () => {
	if (state.pollTimer) return

	state.pollTimer = setInterval(() => {
		checkStatus()
	}, 5000)
}

let stopPolling = () => {
	if (state.pollTimer) {
		clearInterval(state.pollTimer)
		state.pollTimer = null
	}
}

let checkStatus = () => {
	if (!state.token) return

	api.get('get-customer-notification', { pToken: state.token }).then(result => {
		if (result && result.length > 0) {
			let data = result[0]
			if (data.code)
				handleNotification(data.code, data.adminMessage, data)
			else if (data.reservationStatus != 'pending')
				handleStatusChange(data.reservationStatus, data)
		}
	}).catch(() => {})
}

let handleNotification = (code, message, data) => {
	// Stop SSE and polling
	if (state.sse) {
		state.sse.close()
		state.sse = null
	}
	stopPolling()

	// Mark as delivered
	if (state.token)
		api.post('mark-notification-delivered', { pToken: state.token })

	// Use state.formData or data from server
	let resData = state.formData || data || {}

	if (code == 'reservation_confirmed') {
		populateConfirmed(resData, message)
		setStep('confirmed')
	} else if (code == 'reservation_declined') {
		if (message) $declinedMessageText.text(message)
		$declinedMessage.shown(!!message)
		setStep('declined')
	}
}

let handleStatusChange = (status, data) => {
	if (status == 'confirmed')
		handleNotification('reservation_confirmed', null, data)
	else if (status == 'declined')
		handleNotification('reservation_declined', null, data)
}

let loadFromToken = (token) => {
	state.token = token

	api.get('get-customer-notification', { pToken: token }).then(result => {
		if (result && result.length > 0) {
			let data = result[0]

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
				if (data.adminMessage) $declinedMessageText.text(data.adminMessage)
				$declinedMessage.shown(!!data.adminMessage)
				setStep('declined')
			}
		}
	}).catch(() => {
		// Invalid token, show form
		setStep('form')
	})
}

let resetForm = () => {
	state.formData = null
	state.token = null
	// Clear token from URL
	let url = new URL(location.href)
	url.searchParams.delete('token')
	history.replaceState(null, '', url)
	// Reset form
	$form.each(el => el.reset())
	setFormDefaults()
	setStep('form')
}

// Event handlers
$form.submit(data => {
	state.formData = data
	populatePreview(data)
	setStep('preview')
	startCountdown()
})

$flow.action({
	edit: () => {
		clearCountdown()
		setStep('form')
	},
	'submit-now': () => {
		clearCountdown()
		submitReservation()
	},
	retry: () => resetForm(),
	'copy-link': () => {
		navigator.clipboard.writeText(location.href).then(() => {
			$copyLinkText.hidden()
			$copyLinkDone.shown()
			setTimeout(() => {
				$copyLinkText.shown()
				$copyLinkDone.hidden()
			}, 2000)
		})
	},
})

// Initialize
setFormDefaults()

// Check for token in URL
let urlParams = new URLSearchParams(location.search)
let token = urlParams.get('token')
if (token)
	loadFromToken(token)
