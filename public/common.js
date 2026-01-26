let _P = Symbol('part')
let _I = Symbol('index')
let _A = Symbol('aborters')
let _S = Symbol('slots')
let _ACT = Symbol('actions')
let _UNSET = Symbol()

let actionSelectors = {
	click: 'button[value], button[data-action]',
	change: ':is(input, textarea, select):is([name], [data-action])',
	input: ':is(input, textarea, select):is([name], [data-action])',
}

let recipes = {}

let mkArr = x => {
	if (x == null) return []
	try { 
		return [...x]
	} catch (e) {
		return [x]
	}
}

let partsProto = {
	get length() {
		return this[_P].length
	},
	get isTemplate() {
		return this[_P][0] instanceof HTMLTemplateElement
	},
	each(fn) {
		this[_P].forEach(fn)
		return this
	},
	get(key) {
		return this[_P][0]?.[key]
	},
	meth(name, ...args) {
		return this[_P][0]?.[name](...args)
	},
	append(...items) {
		let parent = this[_P][0]
		if (parent)
			for (let item of items)
				parent.appendChild(item[_P] ? item[_P][0] : item)
		return this
	},
	replaceWith(other) {
		this[_P][0]?.replaceWith(other[_P] ? other[_P][0] : other)
		return this
	},
	empty() {
		this.each(el => el.innerHTML = '')
		return this
	},
	remove() {
		this.each(el => el.remove())
		return this
	},
	map(fn) {
		return this[_P].map(fn)
	},
	reduce(fn) {
		return this[_P].reduce(fn)
	},
	filter(fn) {
		return mkPartsAPI(this[_P].filter(fn))
	},
	find(fn) {
		return mkPartsAPI(this[_P].find(fn))
	},
	part(name) {
		return this[_I][name] ?? part(name, this[_P][0])
	},
	querySelector(selector) {
		return mkPartsAPI(this[_P][0]?.querySelectorAll(selector))
	},
	nth(n) {
		let index = n < 0 ? this.length + n : n - 1
		let el = this[_P][index]
		return mkPartsAPI(el)
	},
	first() {
		return this.nth(1)
	},
	last() {
		return this.nth(this.length)
	},
	shown(force) {
		this.each(el => el.hidden = !(force ?? true))
		return this
	},
	hidden(force) {
		this.each(el => el.hidden = (force ?? true))
		return this
	},
	disabled(force) {
		this.each(el => el.disabled = (force ?? true))
		return this
	},
	readOnly(value) {
		if (arguments.length == 0) return this[_P][0]?.readOnly
		this.each(el => el.readOnly = value)
		return this
	},
	val(value) {
		if (arguments.length === 0) {
			let el = this[_P][0]
			if (el?.type == 'checkbox' || el?.type == 'radio')
				return el.checked ? el.value : undefined
			return el?.value
		}
		this.each(el => el.value = value)
		return this
	},
	text(value) {
		if (arguments.length === 0) return this[_P][0]?.textContent
		this.each(el => el.textContent = value)
		return this
	},
	src(value) {
		if (arguments.length === 0) return this[_P][0]?.src
		this.each(el => { if (el.getAttribute('src') != value) el.src = value })
		return this
	},
	validate(fn) {
		this.each(el => {
			let msg = fn(el.value) || ''
			el.setCustomValidity(msg)
		})
		return this
	},
	formData() {
		let form = this[_P][0]
		if (!form) return {}
		let data = new FormData(form)
		let obj = {}
		for (let [k, v] of data.entries())
			obj[k] = v
		return obj
	},
	submit(fn, options) {
		if (arguments.length == 0) {
			this.each(el => el.submit())
			return this
		}
		return this.on('submit', ev => {
			ev.preventDefault()
			fn(this.formData(), ev)
		}, options)
	},
	data(key, value) {
		switch (arguments.length) {
			case 0: return this[_P][0]?.dataset
			case 1: return this[_P][0]?.dataset[key]
			default: this.each(el => {
				switch (value) {
					case false:
					case null:
					case undefined:
						delete el.dataset[key]
						break
					default:
						el.dataset[key] = value
				}
			})
		}
		return this
	},
	cssProp(key, val) {
		switch (arguments.length) {
			case 0: return this
			case 1: return this[_P][0]?.style.getPropertyValue(key)
			default: this.each(el => el.style.setProperty(key, val))
		}
		return this
	},
	on(event, fn, options) {
		let abrt = new AbortController()
		let optionsWithAbrt = {...options, signal: abrt.signal}
		this.each(el => el.addEventListener(event, fn, optionsWithAbrt))
		;(this[_A][event] ??= new Map()).set(fn, abrt)
		return this
	},
	deferred(event, name, fn, options) {
		return this.on(event, ev => {
			let actualTarget = ev.target.closest(`[data-part="${name}"]`)
			if (actualTarget) fn(ev, actualTarget)
		}, options)
	},
	off(event, fn = null) {
		let fnMap = this[_A][event]
		if (fn) fnMap?.get(fn)?.abort()
		else fnMap.forEach(abrt => abrt.abort())
		return this
	},
	action(handlers) {
		this.each(el => {
			if (!el[_ACT]) {
				el[_ACT] = {}
				let resolve = (target) => {
					let name = target.dataset.action || target.value || target.name
					return name && el[_ACT][name]
				}
				for (let [event, selector] of Object.entries(actionSelectors))
					el.addEventListener(event, ev => {
						let target = ev.target.closest(selector)
						if (target && el.contains(target)) {
							let fn = resolve(target)
							if (fn) fn(mkPartsAPI(target), ev)
						}
					})
			}
			Object.assign(el[_ACT], handlers)
		})
		return this
	},
	render() {
		if (this.isTemplate) {
			let root = this[_P][0].content.cloneNode(true).firstElementChild
			let index = {}
			let slots = {}
			for (let el of root.querySelectorAll('[data-part]'))
				(index[el.dataset.part] ??= []).push(el)
			for (let name in index)
				index[name] = mkPartsAPI(index[name])
			for (let slot of root.querySelectorAll('slot[name]')) {
				let name = slot.getAttribute('name')
				let start = document.createComment('slot:' + name)
				let end = document.createComment('slot-end:' + name)
				slot.replaceWith(start)
				start.parentNode.insertBefore(end, start.nextSibling)
				slots[name] = { start, end, nodes: [], prev: {}, variant: _UNSET, items: [], $parts: null }
			}
			return mkPartsAPI(root, index, slots)
		}
		return this
	},
	modal(force) {
		this.each(el => {
			if (force ?? true) { if (!el.open) el.showModal?.() }
			else { if (el.open) el.close?.() }
		})
		return this
	},
	renderFromTemplate(name, variantOrData, maybeData) {
		let variant, data
		if (maybeData == null) {
			variant = null
			data = variantOrData
		} else {
			variant = variantOrData
			data = maybeData
		}

		let recipe = recipes[name]
		if (!recipe) return this

		let slot = this[_S][name]
		if (!slot) return this

		let { updaters } = recipe

		// List mode
		if (Array.isArray(data)) {
			let key = recipe.key || (data[0] && autoKeys.find(k => k in data[0]))
			let oldMap = new Map(slot.items.map(entry => [entry.key, entry]))
			let newItems = []

			for (let item of data) {
				let k = item[key]
				let existing = oldMap.get(k)
				if (existing) {
					applyRecipe(existing.$parts, updaters, existing.prev, item)
					existing.prev = { ...item }
					newItems.push(existing)
					oldMap.delete(k)
				} else {
					let cloned = cloneTemplate(name, variant)
					if (!cloned) continue
					if (recipe.create) recipe.create(cloned.$parts)
					applyRecipe(cloned.$parts, updaters, {}, item)
					newItems.push({ key: k, nodes: [cloned.root], prev: { ...item }, $parts: cloned.$parts })
				}
			}

			for (let entry of oldMap.values())
				for (let node of entry.nodes) node.remove()

			let lastInserted = slot.start
			for (let entry of newItems)
				for (let node of entry.nodes) {
					if (lastInserted.nextSibling != node)
						lastInserted.after(node)
					lastInserted = node
				}

			slot.items = newItems
			slot.nodes = newItems.flatMap(e => e.nodes)
			return this
		}

		// Single mode
		if (slot.variant != variant) {
			for (let node of slot.nodes) node.remove()
			let cloned = cloneTemplate(name, variant)
			if (!cloned) return this
			if (recipe.create) recipe.create(cloned.$parts)
			slot.end.parentNode.insertBefore(cloned.root, slot.end)
			slot.nodes = [cloned.root]
			slot.variant = variant
			slot.$parts = cloned.$parts
			slot.prev = {}
		}
		applyRecipe(slot.$parts, updaters, slot.prev, data)
		slot.prev = { ...data }
		return this
	},
	renderPluralized(name, count, data) {
		let variant = pluralRules.select(count)
		return this.renderFromTemplate(name, variant, data)
	},
}

let mkPartsAPI = (parts, index = {}, slots = {}) => Object.create(partsProto, {
	[_P]: {
		value: Object.freeze(mkArr(parts)),
		writable: false,
		configurable: false,
	},
	[_I]: {
		value: Object.freeze(index),
		writable: false,
		configurable: false,
	},
	[_S]: {
		value: slots,
		configurable: false,
	},
	[_A]: {
		value: {},
		configurable: false,
	},
})

export let extend = (key, fn) => {
	partsProto[key] ??= function(...args) {
		return fn.call(this, this[_P], ...args)
	}
}

export let part = (name, scope = document) =>
	mkPartsAPI(scope?.querySelectorAll(`[data-part="${name}"]`) ?? [])

let bindingProto = {
	bind(targetOrFn, action, transform = x => x) {
		if (typeof targetOrFn == 'function')
			this._bindings.push({ fn: targetOrFn })
		else
			this._bindings.push({ target: targetOrFn, action, transform })
		return this
	},
	setFromEvent(part, event, options, transform = x => x) {
		part.on(event, ev => {
			let raw = options.val ? part.val()
				: options.detail ? ev.detail[options.detail]
				: options.from ? options.from(ev, part)
				: ev
			this.setFrom(part, transform(raw))
		})
		return this
	},
	set(value) {
		this._value = value
		for (let b of this._bindings)
			b.fn ? b.fn(value) : b.target[b.action](b.transform(value))
		return this
	},
	setFrom(source, value) {
		this._value = value
		for (let b of this._bindings)
			if (b.fn || b.target !== source)
				b.fn ? b.fn(value) : b.target[b.action](b.transform(value))
		return this
	},
	get() { return this._value }
}

export let makeChangeTogether = () => Object.create(bindingProto, {
	_bindings: { value: [] },
	_value: { value: undefined, writable: true }
})

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
		}).then(r => r.status == 204 ? {} : r.json())
	}
}

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

// ── Template Rendering ──

let cloneTemplate = (name, variant) => {
	let selector = variant
		? `template[data-name="${name}"][data-variant="${variant}"]`
		: `template[data-name="${name}"]:not([data-variant])`
	let tmpl = document.querySelector(selector)
	if (!tmpl) return null
	let root = tmpl.content.cloneNode(true).firstElementChild
	let index = {}
	for (let el of root.querySelectorAll('[data-part]'))
		(index[el.dataset.part] ??= []).push(el)
	for (let name in index)
		index[name] = mkPartsAPI(index[name])
	return { root, $parts: mkPartsAPI(root, index) }
}

let applyRecipe = ($parts, updaters, prev, data) => {
	for (let k in updaters)
		if (k in data && data[k] !== prev[k]) updaters[k]($parts, data[k])
}

let _CREATE = Symbol('create')
let _KEY = Symbol('key')
let autoKeys = ['id', '_id', 'key', '_key']

export let registerTemplate = (name, recipe) => {
	let updaters = { ...recipe }
	let create = updaters[_CREATE] || null
	let key = updaters[_KEY] || null
	delete updaters[_CREATE]
	delete updaters[_KEY]
	recipes[name] = { key, updaters, create }
}
registerTemplate.create = _CREATE
registerTemplate.key = _KEY

let pluralRules = new Intl.PluralRules()
