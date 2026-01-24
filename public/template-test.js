import { part, registerTemplate } from './common.js'

let results = document.getElementById('results')
let $testArea = part('test-area')

let log = (name, pass, detail) => {
	let li = document.createElement('li')
	li.className = pass ? 'pass' : 'fail'
	li.textContent = (pass ? 'PASS' : 'FAIL') + ': ' + name + (detail ? ' — ' + detail : '')
	results.appendChild(li)
}

let assert = (name, condition, detail) => {
	log(name, !!condition, detail)
}

let testArea = document.querySelector('[data-part="test-area"]')

// ── Setup ──

registerTemplate('guest-count', {
	count: ($, v) => $.part('count').text(v)
})

registerTemplate('reservation-list', {
	name: ($, v) => $.part('name').text(v),
	time: ($, v) => $.part('time').text(v),
})


// ── Test 1: Render with slots creates comment nodes ──

let page = part('page-content').render()
$testArea.append(page)
$testArea.shown()

let html = testArea.innerHTML
assert('Slot replaced with comment', html.includes('<!--slot:guest-count-->'), 'guest-count slot')
assert('List slot replaced with comment', html.includes('<!--slot:reservation-list-->'), 'reservation-list slot')
assert('No <slot> elements remain', !html.includes('<slot'))

// ── Test 2: renderPluralized with count=1 uses "one" variant ──

page.renderPluralized('guest-count', 1, { count: 1 })
assert('Pluralized one: renders text', testArea.textContent.includes('1 guest'))
assert('Pluralized one: not plural', !testArea.textContent.includes('1 guests'))

// ── Test 3: renderPluralized with count=5 uses "other" variant ──

page.renderPluralized('guest-count', 5, { count: 5 })
assert('Pluralized other: renders text', testArea.textContent.includes('5 guests'))

// ── Test 4: Variant switch replaces DOM ──

page.renderPluralized('guest-count', 1, { count: 1 })
assert('Variant switch back to one', testArea.textContent.includes('1 guest') && !testArea.textContent.includes('1 guests'))

// ── Test 5: Partial update (same variant, changed data) ──

page.renderPluralized('guest-count', 3, { count: 3 })
page.renderPluralized('guest-count', 7, { count: 7 })
assert('Partial update same variant', testArea.textContent.includes('7 guests'))

// ── Test 6: List render ──

let reservations = [
	{ id: 1, name: 'John', time: '18:00' },
	{ id: 2, name: 'Jane', time: '19:00' },
]
page.renderFromTemplate('reservation-list', reservations)
assert('List render: first item', testArea.textContent.includes('John'))
assert('List render: second item', testArea.textContent.includes('Jane'))
assert('List render: li count', testArea.querySelectorAll('li').length == 2)

// ── Test 7: List update (change a field) ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 2, name: 'Jane', time: '19:00' },
]
page.renderFromTemplate('reservation-list', reservations)
assert('List update: changed time', testArea.textContent.includes('18:30'))
assert('List update: unchanged item', testArea.textContent.includes('Jane'))

// ── Test 8: List add item ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 2, name: 'Jane', time: '19:00' },
	{ id: 3, name: 'Bob', time: '20:00' },
]
page.renderFromTemplate('reservation-list', reservations)
assert('List add: new item', testArea.textContent.includes('Bob'))
assert('List add: li count', testArea.querySelectorAll('li').length == 3)

// ── Test 9: List remove item ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 3, name: 'Bob', time: '20:00' },
]
page.renderFromTemplate('reservation-list', reservations)
assert('List remove: Jane gone', !testArea.textContent.includes('Jane'))
assert('List remove: li count', testArea.querySelectorAll('li').length == 2)

// ── Test 10: List reorder ──

reservations = [
	{ id: 3, name: 'Bob', time: '20:00' },
	{ id: 1, name: 'John', time: '18:30' },
]
page.renderFromTemplate('reservation-list', reservations)
let lis = testArea.querySelectorAll('li')
assert('List reorder: Bob first', lis[0].textContent.includes('Bob'))
assert('List reorder: John second', lis[1].textContent.includes('John'))

// ── Test 11: No-op when recipe not registered ──

let threw = false
try {
	page.renderFromTemplate('nonexistent', { foo: 'bar' })
} catch (e) {
	threw = true
}
assert('No-op for unregistered recipe', !threw)

// ── Test 12: Comment node structure ──

let comments = []
let walker = document.createTreeWalker(testArea, NodeFilter.SHOW_COMMENT)
let node
while (node = walker.nextNode()) comments.push(node)
assert('Start comment exists', comments.some(c => c.data == 'slot:guest-count'))
assert('End comment exists', comments.some(c => c.data == 'slot-end:guest-count'))
assert('List start comment', comments.some(c => c.data == 'slot:reservation-list'))
assert('List end comment', comments.some(c => c.data == 'slot-end:reservation-list'))
