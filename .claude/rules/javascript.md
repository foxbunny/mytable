# JavaScript rules

This document outlines JavaScript rules.

## Indentation

**ALWAYS use tabs for indentation. Never use spaces.**

## File organization

Organize code in two levels:

1. **Level 1 — by feature**: Group code into feature sections, with shared code at the top
2. **Level 2 — by concern**: Within each feature, order code by concern

```javascript
// ── Shared ──
imports
state
shared refs
shared utilities

// ── Feature A ──
refs
logic
rendering
handlers

// ── Feature B ──
refs
logic
rendering
handlers

// ── Init ──
initialization
```

Since `let` declarations aren't hoisted, order matters — a feature can't call a function defined in a later feature. This is a useful constraint: truly shared functions belong in the shared section, and features stay independent of each other.

For simple pages where there's effectively one feature, this collapses to a flat by-concern ordering (shared section + one feature + init).

## Selecting elements

Elements are selected using `data-part` attributes.

## Variable desclaration

Declare all variables using only `let`. No `const`.

## Async/await vs promises

**Never use async/await** and instead use promises.

## DOM manipulation

Use the utilities in public/common.js: `$` and `$$` for element selection, `api` for fetch calls, `renderList` for list reconciliation, and `showToast` for notifications.

Prefer declarative patterns over imperative logic. For example, use `el.toggleAttribute('data-selected', isSelected)` instead of `if (isSelected) el.dataset.selected = ''; else delete el.dataset.selected`.

## Template rendering

Pages wrap their content in a `<template data-part="content">` and render it on init:

```javascript
import { $, renderList } from './common.js'

let contentTpl = $('@content')
let page = contentTpl.content.cloneNode(true).firstElementChild
contentTpl.replaceWith(page)

// Access elements within the rendered page
let sidebar = $('@sidebar', page)
```

### List rendering with `renderList`

Use `renderList(container, items, templateId, recipe)` for dynamic lists with efficient reconciliation:

```javascript
let reservationListRecipe = {
	create: (el) => {
		el.addEventListener('click', () => handleClick(el.dataset.reservationId))
	},
	time: (el, v) => $('@res-time', el).textContent = v,
	guest: (el, v) => $('@res-guest', el).textContent = v,
	reservationId: (el, v) => el.dataset.reservationId = v,
	urgent: (el, v) => el.toggleAttribute('data-urgent', v),
}

renderList(listContainer, reservations, 'reservation-list', reservationListRecipe)
```

The `create` function runs once when an item is first created. Other recipe keys run when their corresponding data value changes.

### Recipes

A recipe maps data keys to updater functions. Each updater receives the element and the value. Prefer declarative one-liners over imperative logic:

```javascript
let tableMarkersRecipe = {
	// Text content
	name: (el, v) => $('@marker-name', el).textContent = v,

	// CSS custom properties for positioning/sizing
	x: (el, v) => el.style.setProperty('--x', v),
	y: (el, v) => el.style.setProperty('--y', v),

	// Data attributes for values
	tableId: (el, v) => el.dataset.tableId = v,

	// Boolean attributes via toggleAttribute
	blocked: (el, v) => el.toggleAttribute('data-blocked', v),
	selected: (el, v) => el.toggleAttribute('data-selected', v),
	occupied: (el, v) => el.toggleAttribute('data-occupied', v),
}
```

Use `toggleAttribute('data-foo', bool)` for boolean states — it's cleaner than `if (v) el.dataset.foo = ''; else delete el.dataset.foo`.

On updates, only changed fields trigger their updater.

### Key detection

For list reconciliation, the system auto-detects the identity field by trying `id`, `_id`, `key`, `_key` on the first item. For non-standard key names, set `key` in the recipe:

```javascript
let recipe = {
	key: 'entityId',
	name: (el, v) => $('@name', el).textContent = v,
}
```

### List reconciliation

`renderList` reconciles by key: new items are created, removed items are deleted, existing items are diffed. DOM reordering minimizes moves — nodes already in position are left untouched.

## Inline assertions

Use console.assert() to make assertions about the inputs and outputs. Make no more than 2 asserts. If more than 2 assertions appear to be necessary, considering breaking the functions up. Make assertions simple and side-effects-free.

## Optional curlies

Curly braces **should be** omitted whenever that's possible. The exception is when there are other branches in the if block where curlies are used.

## Triple-equals and coercion

**Always use double-equals** and rely on coercion rather than shying from it.

For null checks, always use `== null` (which catches both `null` and `undefined`). Never compare against `undefined` directly.

## Arrow functions

Always use arrow functions unless access to `this` is needed. Within a given context (e.g., methods on an object literal), be consistent — if any method needs `this`, use regular functions for all of them.

## Code quantity

This is a build-less setup. Whenever possible, reduce the amount of code. Readability is a high priority, but code reduction should be a close second.

## Date handling

When working with dates, the internal representation should be the RFC date string from `toDateString()` (e.g., "Sun Jan 19 2026"). This format can be passed directly to `new Date()` and is interpreted in local time, avoiding off-by-one timezone bugs. Do not use ISO format (`YYYY-MM-DD`) as it gets interpreted as UTC.

## HTML fragments

When custom elements or components need HTML structure, avoid using `innerHTML` with template literals. Instead:

1. Create an HTML fragment file named with underscore prefix: `_foo.html`
2. Fetch the fragment from JavaScript and cache it
3. Clone the fragment's content for each instance

This keeps HTML in HTML files where it belongs and avoids mixing markup with code.

## Tab/state switching via data attributes

When switching between tabs or states that show/hide content sections, **avoid toggling visibility directly in JavaScript**. Instead:

1. Set a `data-*` attribute on the common container (e.g., `data-tab="queue"`)
2. Let CSS handle visibility using `:not()` selectors

This keeps the JavaScript minimal (just setting an attribute value) and lets CSS handle the presentation logic.

## Text labels and messages

**Never place static text content in JavaScript.** All user-facing text belongs in HTML. JavaScript only injects **raw data values** — things that come from the database or user input (names, numbers, dates).

The test: if a translator could translate it, it belongs in HTML. If it's a raw value from the system, `textContent` is fine.

**`textContent` is acceptable for:**
- Names from the database: `guestNameEl.textContent = res.guestName`
- Formatted numbers: `capacityEl.textContent = totalSeats`
- Computed values: `endTimeEl.textContent = addMinutes(time, duration)`

**`textContent` is NOT acceptable for:**
- Labels: `btn.textContent = 'Save'` — put the word in HTML
- Status text: `status.textContent = 'Loading...'` — use state switching
- Constructed sentences: `` msg.textContent = `${n} guests` `` — put structure in HTML, inject only the number

### Switching between text alternatives

When a UI element shows different text based on state, all alternatives live in HTML as siblings. A `data-*` attribute on a container controls which one is visible, and CSS hides the rest.

```html
<h2 id="title-new">New Reservation</h2>
<h2 id="title-edit">Edit Reservation</h2>
```

```css
#container:not([data-mode="new"]) #title-new,
#container:not([data-mode="edit"]) #title-edit {
  display: none;
}
```

```javascript
container.dataset.mode = 'new'
```

### Structured messages with data placeholders

When a message mixes static text with dynamic values, the static parts are HTML and the dynamic parts are empty spans that JS fills:

```html
<p data-part="msg-selected" hidden>
  <span>Table</span><span data-part="table-suffix">s</span>
  <span data-part="table-names"></span>
  <span> — </span>
  <span data-part="capacity-current"></span>/<span data-part="capacity-needed"></span>
  <span> seats</span>
</p>
```

```javascript
msgSelected.hidden = count == 0
tableSuffix.hidden = count <= 1
tableNames.textContent = names
capacityCurrent.textContent = capacity
capacityNeeded.textContent = needed
```

### Button loading states

Buttons that show different text during async operations use two child spans and a `data-*` attribute:

```html
<button type="submit" data-part="submit">
  <span class="label-idle">Save</span>
  <span class="label-busy">Saving...</span>
</button>
```

```css
#my-form .label-busy { display: none; }
#my-form[data-state="loading"] .label-idle { display: none; }
#my-form[data-state="loading"] .label-busy { display: inline; }
```

```javascript
container.dataset.state = 'loading'
submit.disabled = true
```

### Form error messages

Forms that can show different error types use child spans with classes, controlled by a `data-*` attribute on the form container:

```html
<p class="message" data-part="message">
  <span class="msg-network">Network error</span>
  <span class="msg-api" data-part="error-text"></span>
</p>
```

```css
#my-form .message { display: none; }
#my-form[data-state="error-network"] .message,
#my-form[data-state="error-api"] .message { display: block; }
#my-form:not([data-state="error-network"]) .msg-network,
#my-form:not([data-state="error-api"]) .msg-api { display: none; }
```

```javascript
// Network error — no dynamic text needed
container.dataset.state = 'error-network'

// API error — inject the error string as a data value
errorText.textContent = result.error
container.dataset.state = 'error-api'

// Clear
delete container.dataset.state
```

## Styling via CSS custom properties

**Never directly set style properties in JavaScript.** Instead, set CSS custom properties on the element, and let CSS use those properties to apply the actual styles.

**Bad: Direct style manipulation**
```javascript
el.style.left = offsetX + 'px'
el.style.top = offsetY + 'px'
el.style.width = renderW + 'px'
el.style.height = renderH + 'px'
```

**Good: Set custom properties, CSS applies styles**
```javascript
el.style.setProperty('--x', offsetX)
el.style.setProperty('--y', offsetY)
el.style.setProperty('--w', renderW)
el.style.setProperty('--h', renderH)
```

```css
.overlay {
	left: calc(var(--x) * 1px);
	top: calc(var(--y) * 1px);
	width: calc(var(--w) * 1px);
	height: calc(var(--h) * 1px);
}
```

This pattern:
- Keeps all style declarations in CSS where they belong
- Makes it easy to add transitions, transforms, or other CSS features
- JavaScript only provides data values, CSS decides how to use them

## Declarative state patterns

Prefer declarative assignments over imperative if/else:

```javascript
// Bad: imperative dispatch
if (hasNotes) notesEl.hidden = false
else notesEl.hidden = true

// Good: declarative assignment
notesEl.hidden = !hasNotes
```

For boolean data attributes, use `toggleAttribute`:

```javascript
// Bad: imperative
if (isBlocked) el.dataset.blocked = ''
else delete el.dataset.blocked

// Good: declarative
el.toggleAttribute('data-blocked', isBlocked)
```

### Pick the property that avoids negation

```javascript
let empty = items.length == 0
listEl.hidden = empty
emptyMsg.hidden = !empty
```

## Delegated event handlers

Use event delegation to consolidate button clicks within a container. Mark elements with `data-action` and handle them in a single listener:

```html
<aside data-part="sidebar">
	<button data-action="back">Back</button>
	<button data-action="confirm">Confirm</button>
	<button data-action="cancel">Cancel</button>
</aside>
```

```javascript
sidebar.addEventListener('click', ev => {
	let btn = ev.target.closest('[data-action]')
	if (!btn) return
	let action = btn.dataset.action

	if (action == 'back') exitDetailView()
	else if (action == 'confirm') confirmBooking()
	else if (action == 'cancel') cancelBooking()
})
```

This pattern:
- Reduces the number of event listeners
- Makes it easy to add new actions
- Keeps action handling in one place
