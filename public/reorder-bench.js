import { part, registerTemplate } from './common.js'

let N = 100
let ITERS = 500

// ── Reorder strategies ──

let cursorReorder = (parent, start, end, newEntries, oldEntries) => {
	let oldMap = new Map(oldEntries.map(e => [e.key, e]))
	for (let e of newEntries) oldMap.delete(e.key)
	for (let e of oldMap.values()) e.node.remove()

	let cursor = start.nextSibling
	for (let e of newEntries)
		if (e.node != cursor)
			parent.insertBefore(e.node, cursor)
		else
			cursor = cursor.nextSibling
}

let afterReorder = (parent, start, end, newEntries, oldEntries) => {
	let oldMap = new Map(oldEntries.map(e => [e.key, e]))
	for (let e of newEntries) oldMap.delete(e.key)
	for (let e of oldMap.values()) e.node.remove()

	let lastInserted = start
	for (let e of newEntries) {
		if (lastInserted.nextSibling != e.node)
			lastInserted.after(e.node)
		lastInserted = e.node
	}
}

// ── Template cloning (mirrors common.js logic) ──

let cloneItem = (data) => {
	let tmpl = document.querySelector('template[data-name="bench-list"]:not([data-variant])')
	let root = tmpl.content.cloneNode(true).firstElementChild
	let parts = {}
	for (let el of root.querySelectorAll('[data-part]'))
		parts[el.dataset.part] = el
	parts.name.textContent = data.name
	parts.time.textContent = data.time
	parts.guests.textContent = data.guests
	return { key: data.id, node: root, parts }
}

let updateItem = (entry, data) => {
	entry.parts.name.textContent = data.name
	entry.parts.time.textContent = data.time
	entry.parts.guests.textContent = data.guests
}

// ── Data generation ──

let makeData = (n) => {
	let items = []
	for (let i = 0; i < n; i++)
		items.push({ id: i, name: 'Guest ' + i, time: (18 + (i % 4)) + ':' + String(i % 60).padStart(2, '0'), guests: 1 + (i % 6) })
	return items
}

// ── Test harness ──

let countMoves = (fn) => {
	let moves = 0
	let origInsert = Node.prototype.insertBefore
	let origElAfter = Element.prototype.after
	let origCdAfter = CharacterData.prototype.after
	Node.prototype.insertBefore = function(node, ref) { moves++; return origInsert.call(this, node, ref) }
	Element.prototype.after = function(...nodes) { moves += nodes.length; return origElAfter.call(this, ...nodes) }
	CharacterData.prototype.after = function(...nodes) { moves += nodes.length; return origCdAfter.call(this, ...nodes) }
	fn()
	Node.prototype.insertBefore = origInsert
	Element.prototype.after = origElAfter
	CharacterData.prototype.after = origCdAfter
	return moves
}

let runScenario = (name, reorderFn, baseData, newDataFn) => {
	// Setup: render initial list
	let container = document.createElement('div')
	document.body.appendChild(container)

	let start = document.createComment('slot:bench-list')
	let end = document.createComment('slot-end:bench-list')
	container.appendChild(start)
	container.appendChild(end)

	let buildEntries = (data) => data.map(d => cloneItem(d))

	let setupBase = () => {
		while (start.nextSibling != end)
			start.nextSibling.remove()
		let entries = buildEntries(baseData)
		for (let e of entries)
			container.insertBefore(e.node, end)
		return entries
	}

	// Measure moves (single run)
	let oldEntries = setupBase()
	let newData = newDataFn(baseData)
	let newEntries = newData.map(d => {
		let existing = oldEntries.find(e => e.key == d.id)
		if (existing) { updateItem(existing, d); return existing }
		return cloneItem(d)
	})
	let moves = countMoves(() => {
		reorderFn(container, start, end, newEntries, oldEntries)
	})

	// Measure time
	let times = []
	for (let i = 0; i < ITERS; i++) {
		let old = setupBase()
		let nd = newDataFn(baseData)
		let fresh = nd.map(d => {
			let existing = old.find(e => e.key == d.id)
			if (existing) { updateItem(existing, d); return existing }
			return cloneItem(d)
		})
		let t0 = performance.now()
		reorderFn(container, start, end, fresh, old)
		times.push(performance.now() - t0)
	}

	container.remove()
	let avgTime = times.reduce((a, b) => a + b, 0) / times.length
	return { moves, time: avgTime }
}

// ── Scenarios ──

let baseData = makeData(N)

let scenarios = {
	'Append at end': (data) => [...data, { id: N, name: 'New Guest', time: '21:00', guests: 4 }],
	'Insert in middle': (data) => {
		let mid = Math.floor(data.length / 2)
		return [...data.slice(0, mid), { id: N, name: 'New Guest', time: '21:00', guests: 4 }, ...data.slice(mid)]
	},
	'Reverse': (data) => [...data].reverse(),
}

// ── Run and display ──

let resultsDiv = document.getElementById('results')
let table = document.createElement('table')
let thead = document.createElement('thead')
thead.innerHTML = '<tr><th>Scenario</th><th>Strategy</th><th>Moves</th><th>Time (ms)</th></tr>'
table.appendChild(thead)
let tbody = document.createElement('tbody')
table.appendChild(tbody)

for (let [scenarioName, newDataFn] of Object.entries(scenarios)) {
	let cursorResult = runScenario(scenarioName, cursorReorder, baseData, newDataFn)
	let afterResult = runScenario(scenarioName, afterReorder, baseData, newDataFn)

	for (let [stratName, result] of [['cursor', cursorResult], ['after', afterResult]]) {
		let other = stratName == 'cursor' ? afterResult : cursorResult
		let tr = document.createElement('tr')
		let movesClass = result.moves <= other.moves ? 'winner' : ''
		let timeClass = result.time <= other.time ? 'winner' : ''
		tr.innerHTML = `<td>${scenarioName}</td><td>${stratName}</td><td class="${movesClass}">${result.moves}</td><td class="${timeClass}">${result.time.toFixed(4)}</td>`
		tbody.appendChild(tr)
	}
}

resultsDiv.appendChild(table)
document.getElementById('status').textContent = 'Done. ' + N + ' items, ' + ITERS + ' iterations.'
