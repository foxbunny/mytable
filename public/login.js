import { $ } from './common.js'

let status = $('@status')
let contentTpl = $('@content')

let rendered = contentTpl.content.cloneNode(true).firstElementChild
contentTpl.replaceWith(rendered)
status.hidden = true

let form = $('@form', rendered)
let submit = $('@submit', rendered)

form.addEventListener('submit', ev => {
	ev.preventDefault()
	let data = Object.fromEntries(new FormData(form))

	rendered.dataset.state = 'loading'
	submit.disabled = true

	fetch('/api/admin-login', {
		method: 'POST',
		headers: {'Content-Type': 'application/json'},
		body: JSON.stringify({pUsername: data.username.trim(), pPassword: data.password})
	}).then(r => {
		if (r.ok) {
			window.location.replace('back-office.html')
		} else {
			rendered.dataset.state = 'error-credentials'
			submit.disabled = false
		}
	}).catch(() => {
		rendered.dataset.state = 'error-network'
		submit.disabled = false
	})
})
