let go = url => location.replace(url)
fetch('/api/is-setup')
	.then(r => r.json())
	.then(v => {
		if (!v.setup) go('setup.html')
		return fetch('/api/is-authenticated')
	})
	.then(r => {
		if (r && !r.ok) go('login.html')
		return fetch('/api/is-restaurant-configured')
	})
	.then(r => r?.json())
	.then(v => {
		if (v && !v.configured) go('restaurant-setup.html')
	})
	.catch(() => go('error.html'))
