let go = url => location.replace(url)
fetch('/api/is-setup')
	.then(r => r.json())
	.then(v => {
		if (!v.setup) go('setup.html')
		return fetch('/api/is-authenticated')
	})
	.then(r => {
		if (r && !r.ok) go('login.html')
	})
	.catch(() => go('error.html'))
