// ── Element selection ──

export let $ = (sel, scope = document) =>
	sel[0] == '@' ? scope.querySelector(`[data-part="${sel.slice(1)}"]`) : scope.querySelector(sel)

export let $$ = (sel, scope = document) =>
	[...(sel[0] == '@' ? scope.querySelectorAll(`[data-part="${sel.slice(1)}"]`) : scope.querySelectorAll(sel))]

// ── Delegated events ──

export let delegate = (sel, fn) => ev => {
	let target = ev.target.closest(sel)
	if (target) fn(ev, target)
}

// ── API ──

export let api = {
	get(endpoint, params = {}) {
		let url = new URL('/api/' + endpoint, location.origin)
		for (let [k, v] of Object.entries(params))
			if (v != null) url.searchParams.set(k, v)
		return fetch(url).then(r => r.json())
	},
	post(endpoint, body = {}) {
		return fetch('/api/' + endpoint, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(body)
		}).then(r => {
			if (r.status == 204) return {}
			let ct = r.headers.get('content-type') || ''
			return ct.includes('application/json') ? r.json() : r.text().then(() => ({}))
		})
	}
}

// ── List rendering with reconciliation ──

let listState = new WeakMap()
let autoKeys = ['id', '_id', 'key', '_key']

export let renderList = (container, items, templateId, recipe) => {
	let state = listState.get(container)
	if (!state) {
		state = { entries: [], template: null }
		listState.set(container, state)
	}

	if (!state.template)
		state.template = document.querySelector(`template[data-name="${templateId}"]`)
	if (!state.template) return

	let keyField = recipe.key || (items[0] && autoKeys.find(k => k in items[0]))
	let oldMap = new Map(state.entries.map(e => [e.key, e]))
	let newEntries = []

	for (let item of items) {
		let k = item[keyField]
		let existing = oldMap.get(k)
		if (existing) {
			applyRecipe(existing.el, existing.prev, item, recipe)
			existing.prev = { ...item }
			newEntries.push(existing)
			oldMap.delete(k)
		} else {
			let el = state.template.content.cloneNode(true).firstElementChild
			if (recipe.create) recipe.create(el)
			applyRecipe(el, {}, item, recipe)
			newEntries.push({ key: k, el, prev: { ...item } })
		}
	}

	for (let entry of oldMap.values())
		entry.el.remove()

	let lastInserted = null
	for (let entry of newEntries) {
		let nextSibling = lastInserted ? lastInserted.nextSibling : container.firstChild
		if (nextSibling != entry.el)
			container.insertBefore(entry.el, nextSibling)
		lastInserted = entry.el
	}

	state.entries = newEntries
}

let applyRecipe = (el, prev, data, recipe) => {
	for (let k in recipe) {
		if (k == 'create' || k == 'key') continue
		if (k in data && data[k] !== prev[k])
			recipe[k](el, data[k])
	}
}

// ── Toast ──

let toastList = null
let toastTpl = null

let dismissToast = (toast) => {
	toast.dataset.clear = ''
	setTimeout(() => toast.remove(), 300)
}

export let showToast = (message, level = 'error') => {
	if (!toastList) toastList = document.getElementById('toast-list')
	if (!toastTpl) toastTpl = document.querySelector('[data-part="toast-template"]')

	let toast = toastTpl.content.cloneNode(true).firstElementChild
	toast.querySelector('[data-part="toast-message"]').textContent = message
	toast.dataset.level = level

	toast.querySelector('[data-part="toast-dismiss"]').addEventListener('click', () => dismissToast(toast))
	toast.addEventListener('animationend', ev => {
		if (ev.animationName == 'expire') dismissToast(toast)
	})

	toastList.appendChild(toast)
}

// ── Icon custom element ──

let spritePromise = null

let loadSprite = () => {
	if (spritePromise) return spritePromise
	spritePromise = fetch('icons.svg')
		.then(r => r.text())
		.then(svg => {
			let container = document.createElement('div')
			container.hidden = true
			container.innerHTML = svg
			document.body.insertBefore(container, document.body.firstChild)
		})
	return spritePromise
}

class XIcon extends HTMLElement {
	connectedCallback() {
		let name = this.getAttribute('name')
		console.assert(name, 'x-icon requires a name attribute')
		loadSprite().then(() => {
			this.innerHTML = `<svg aria-hidden="true"><use href="#${name}"></use></svg>`
		})
	}
}

customElements.define('x-icon', XIcon)
