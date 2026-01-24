fetch('/api/is-setup')
	.then(r => r.json())
	.then(v => {
		if (v.setup) location.replace('login.html')
	})
	.catch(() => location.replace('error.html'))
