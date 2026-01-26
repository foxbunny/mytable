console.log('backoffice check')
let go = url => location.replace(url)
fetch('/api/is-setup')
	.then(r => { console.log('is-setup response', r.status); return r.json() })
	.then(v => {
		console.log('is-setup json', v)
		if (!v.setup) { go('setup.html'); return Promise.reject('redirect') }
		return fetch('/api/is-authenticated')
	})
	.then(r => {
		console.log('is-authenticated response', r.status)
		if (!r.ok) { go('login.html'); return Promise.reject('redirect') }
		return fetch('/api/is-restaurant-configured')
	})
	.then(r => r.json())
	.then(v => {
		console.log('is-restaurant-configured json', v)
		if (!v.configured) go('restaurant-setup.html')
	})
	.catch(e => { console.log('catch', e); if (e != 'redirect') go('error.html') })
