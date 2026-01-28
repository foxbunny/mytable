import { api, $ } from './common.js'

let statusLoading = $('@status-loading')
let statusError = $('@status-error')
let contentTpl = $('@content')

api.get('is-setup').then(result => {
	if (result.setup) {
		window.location.replace('back-office.html')
		return
	}

	let rendered = contentTpl.content.cloneNode(true).firstElementChild
	contentTpl.replaceWith(rendered)
	statusLoading.hidden = true

	let form = $('@form', rendered)
	let passwordInput = $('@password', rendered)
	let confirmInput = $('@confirm', rendered)
	let msgApiText = $('@msg-api-text', rendered)
	let submit = $('@submit', rendered)

	let validateConfirm = () => {
		let msg = confirmInput.value != passwordInput.value ? 'Passwords do not match' : ''
		confirmInput.setCustomValidity(msg)
	}

	confirmInput.addEventListener('input', validateConfirm)
	passwordInput.addEventListener('input', validateConfirm)

	form.addEventListener('submit', ev => {
		ev.preventDefault()
		let data = Object.fromEntries(new FormData(form))

		validateConfirm()
		if (!form.reportValidity()) return

		rendered.dataset.state = 'loading'
		submit.disabled = true

		api.post('setup-admin', {
			pUsername: data.username.trim(),
			pPassword: data.password
		}).then(result => {
			if (result.error) {
				msgApiText.textContent = result.error.split(': ')[1] || result.error
				rendered.dataset.state = 'error-api'
				submit.disabled = false
			} else {
				rendered.dataset.state = 'success'
				setTimeout(() => {
					window.location.href = 'login.html'
				}, 1500)
			}
		}).catch(() => {
			rendered.dataset.state = 'error-network'
			submit.disabled = false
		})
	})
}).catch(() => {
	statusLoading.hidden = true
	statusError.hidden = false
})
