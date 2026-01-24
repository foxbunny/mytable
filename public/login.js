import { part } from './common.js'

let status = part('status')
let content = part('content')

let rendered = content.render()
content.replaceWith(rendered)
status.hidden()

let form = rendered.part('form')
let submit = rendered.part('submit')

form.submit(data => {
	rendered.data('state', 'loading')
	submit.disabled()

	fetch('/api/admin-login', {
		method: 'POST',
		headers: {'Content-Type': 'application/json'},
		body: JSON.stringify({pUsername: data.username.trim(), pPassword: data.password})
	}).then(r => {
		if (r.ok) {
			window.location.replace('back-office.html')
		} else {
			rendered.data('state', 'error-credentials')
			submit.disabled(false)
		}
	}).catch(() => {
		rendered.data('state', 'error-network')
		submit.disabled(false)
	})
})
