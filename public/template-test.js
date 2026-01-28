import { $, renderList } from './common.js'

let results = document.getElementById('results')
let testArea = document.querySelector('[data-part="test-area"]')
let listContainer = document.getElementById('list-container')

let log = (name, pass, detail) => {
	let li = document.createElement('li')
	li.className = pass ? 'pass' : 'fail'
	li.textContent = (pass ? 'PASS' : 'FAIL') + ': ' + name + (detail ? ' — ' + detail : '')
	results.appendChild(li)
}

let assert = (name, condition, detail) => {
	log(name, !!condition, detail)
}

// ── Setup recipe ──

let reservationRecipe = {
	name: (el, v) => $('@name', el).textContent = v,
	time: (el, v) => $('@time', el).textContent = v,
}

// ── Test 1: Initial render ──

let reservations = [
	{ id: 1, name: 'John', time: '18:00' },
	{ id: 2, name: 'Jane', time: '19:00' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
assert('Initial render: first item', testArea.textContent.includes('John'))
assert('Initial render: second item', testArea.textContent.includes('Jane'))
assert('Initial render: li count', listContainer.children.length == 2)

// ── Test 2: Update (change a field) ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 2, name: 'Jane', time: '19:00' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
assert('Update: changed time', testArea.textContent.includes('18:30'))
assert('Update: unchanged item', testArea.textContent.includes('Jane'))

// ── Test 3: Add item ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 2, name: 'Jane', time: '19:00' },
	{ id: 3, name: 'Bob', time: '20:00' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
assert('Add: new item', testArea.textContent.includes('Bob'))
assert('Add: li count', listContainer.children.length == 3)

// ── Test 4: Remove item ──

reservations = [
	{ id: 1, name: 'John', time: '18:30' },
	{ id: 3, name: 'Bob', time: '20:00' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
assert('Remove: Jane gone', !testArea.textContent.includes('Jane'))
assert('Remove: li count', listContainer.children.length == 2)

// ── Test 5: Reorder ──

reservations = [
	{ id: 3, name: 'Bob', time: '20:00' },
	{ id: 1, name: 'John', time: '18:30' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
let lis = [...listContainer.children]
assert('Reorder: Bob first', lis[0].textContent.includes('Bob'))
assert('Reorder: John second', lis[1].textContent.includes('John'))

// ── Test 6: Empty list ──

renderList(listContainer, [], 'reservation-list', reservationRecipe)
assert('Empty: li count', listContainer.children.length == 0)

// ── Test 7: Re-render after empty ──

reservations = [
	{ id: 4, name: 'Alice', time: '21:00' },
]
renderList(listContainer, reservations, 'reservation-list', reservationRecipe)
assert('Re-render after empty', testArea.textContent.includes('Alice'))
assert('Re-render: li count', listContainer.children.length == 1)

// ── Test 8: Create hook ──

let createCalled = 0
let clickCount = 0
let hookRecipe = {
	create: (el) => {
		createCalled++
		el.addEventListener('click', () => clickCount++)
	},
	name: (el, v) => $('@name', el).textContent = v,
	time: (el, v) => $('@time', el).textContent = v,
}

createCalled = 0
renderList(listContainer, [{ id: 10, name: 'Test', time: '10:00' }], 'reservation-list', hookRecipe)
assert('Create hook: called once', createCalled == 1)

// Re-render same item (update)
renderList(listContainer, [{ id: 10, name: 'Test Updated', time: '10:30' }], 'reservation-list', hookRecipe)
assert('Create hook: not called on update', createCalled == 1)

// Add new item
renderList(listContainer, [
	{ id: 10, name: 'Test Updated', time: '10:30' },
	{ id: 11, name: 'New', time: '11:00' }
], 'reservation-list', hookRecipe)
assert('Create hook: called for new item', createCalled == 2)

// Test click handler persists
clickCount = 0
listContainer.children[0].click()
assert('Create hook: click handler works', clickCount == 1)

testArea.hidden = false
