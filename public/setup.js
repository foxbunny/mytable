import { api, part } from './common.js'

let $statusLoading = part('status-loading')
let $statusError = part('status-error')
let content = part('content')

api.get('is-setup').then(result => {
	if (result.setup) {
		window.location.replace('back-office.html')
		return
	}

	let rendered = content.render()
	content.replaceWith(rendered)
	$statusLoading.hidden()

	let form = rendered.part('form')
	let passwordInput = rendered.part('password')
	let confirmInput = rendered.part('confirm')
	let $msgApiText = rendered.part('msg-api-text')
	let submit = rendered.part('submit')

	let validateConfirm = () => confirmInput.validate(v =>
		v != passwordInput.val() ? 'Passwords do not match' : undefined
	)

	confirmInput.on('input', validateConfirm)
	passwordInput.on('input', validateConfirm)

	form.submit(data => {
		validateConfirm()
		if (!form.meth('reportValidity')) return

		rendered.data('state', 'loading')
		submit.disabled()

		api.post('setup-admin', {
			pUsername: data.username.trim(),
			pPassword: data.password
		}).then(result => {
			if (result.error) {
				$msgApiText.text(result.error.split(': ')[1] || result.error)
				rendered.data('state', 'error-api')
				submit.disabled(false)
			} else {
				rendered.data('state', 'success')
				setTimeout(() => {
					window.location.href = 'login.html'
				}, 1500)
			}
		}).catch(() => {
			rendered.data('state', 'error-network')
			submit.disabled(false)
		})
	})
}).catch(() => {
	$statusLoading.hidden()
	$statusError.shown()
})
