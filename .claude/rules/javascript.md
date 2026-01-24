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

Use the lightweight jQuery clone located in public/common.js.

When you are about to do low-level DOM manipulation directly on elements, first think whether this is an opportunity to enahnce the partsProto with new features. The criterion is that the feature is generic enough, and high-level enough (e.g., not something that is normally trivial to do with direct DOM manipulation), and that there's a value-add when we are able to perform it across all selected elements at once (i.e., it's not typically something we do with single elements).

The API design should be such that it can always be used declaratively whenever that makes sense. For instance, instead of having disable() and enable(), we have toggleDisable(true), toggleDisable(false). This allows us to data-drive the operations.

## Template rendering with slots

Pages wrap their content in a `<template data-part="content">` and render it on init. This creates slots (comment markers) and builds a part index for efficient element access.

```javascript
import { part, registerTemplate } from './common.js'

// Register recipes for slot templates
registerTemplate('reservation-list', {
	[registerTemplate.create]: ($) => {
		$.on('click', () => { ... })
		$.on('mouseenter', () => { ... })
	},
	name: ($, v) => $.part('name').text(v),
	time: ($, v) => $.part('time').text(v),
})

// Render the page template (processes slots, indexes parts)
let page = part('content').render()
part('content').replaceWith(page)

// Access parts via the rendered instance
let $sidebar = page.part('sidebar')

// Render lists into slots
page.renderFromTemplate('reservation-list', reservations)

// Variant rendering (e.g., pluralization)
page.renderPluralized('guest-count', count, { count })
```

### Recipes

A recipe maps data keys to updater functions. Each updater receives the item's parts API and the value:

```javascript
registerTemplate('table-marker', {
	name: ($, v) => $.part('marker-name').text(v),
	x: ($, v) => $.cssProp('--x', v),
	y: ($, v) => $.cssProp('--y', v),
})
```

On updates, only changed fields trigger their updater.

### Key detection

For list reconciliation, the system auto-detects the identity field by trying `id`, `_id`, `key`, `_key` on the first item. For non-standard key names, use the symbol:

```javascript
registerTemplate('custom-list', {
	[registerTemplate.key]: 'entityId',
	name: ($, v) => $.part('name').text(v),
})
```

### Create hook

The `registerTemplate.create` symbol registers an initialization function called once per item when first cloned. Use it for event handlers:

```javascript
registerTemplate('item-list', {
	[registerTemplate.create]: ($) => {
		$.on('click', () => handleClick($.data('itemId')))
		$.on('mouseenter', () => highlight(true))
		$.on('mouseleave', () => highlight(false))
	},
	name: ($, v) => $.part('name').text(v),
})
```

### List reconciliation

When `renderFromTemplate` receives an array, it reconciles by key: new items are created, removed items are deleted, existing items are diffed. DOM reordering minimizes moves — nodes already in position are left untouched.

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

The test: if a translator could translate it, it belongs in HTML. If it's a raw value from the system, `.text()` is fine.

**`.text()` is acceptable for:**
- Names from the database: `$guestName.text(res.guestName)`
- Formatted numbers: `$capacity.text(totalSeats)`
- Computed values: `$endTime.text(addMinutes(time, duration))`

**`.text()` is NOT acceptable for:**
- Labels: `$btn.text('Save')` — put the word in HTML
- Status text: `$status.text('Loading...')` — use state switching
- Constructed sentences: `` $msg.text(`${n} guests`) `` — put structure in HTML, inject only the number

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
$container.data('mode', 'new')
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
$msgSelected.toggle(count > 0)
$tableSuffix.toggle(count > 1)
$tableNames.text(names)
$capacityCurrent.text(capacity)
$capacityNeeded.text(needed)
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
$container.data('state', 'loading')
$submit.toggleDisable(true)
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
$container.data('state', 'error-network')

// API error — inject the error string as a data value
$errorText.text(result.error)
$container.data('state', 'error-api')

// Clear
$container.data('state', false)
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

**Good: Set custom properties via `cssProp`, CSS applies styles**
```javascript
$el.cssProp('--x', offsetX)
$el.cssProp('--y', offsetY)
$el.cssProp('--w', renderW)
$el.cssProp('--h', renderH)
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

## Declarative state methods

Methods `shown()`, `hidden()`, `disabled()`, `modal()`, and `data()` are state-specifying: each call is a declarative assertion about what the element's state should be. The method name is the state (adjective), and the argument determines whether to apply it.

### Pass conditions as arguments, not as control flow

```javascript
// Bad: imperative dispatch
if (hasNotes) $notes.shown()
else $notes.hidden()

// Good: declarative state assertion
$notes.shown(!!hasNotes)
```

### Pick the method that avoids negation

```javascript
let empty = items.length == 0
$list.hidden(empty)          // not: $list.shown(!empty)
$emptyMsg.shown(empty)
```

### Separate data-injection from state-specification

```javascript
if (data.notes) $notesText.text(data.notes)
$notesRow.shown(!!data.notes)
```

### No-arg form means "unconditionally assert this state"

```javascript
$loading.hidden()            // unconditionally hidden
$error.shown()               // unconditionally shown
$submit.disabled()           // unconditionally disabled
```

### Exception: setup blocks

When a state call is part of a block that also configures the element's content, it may remain inside the conditional — provided the reset path already asserts the opposite state unconditionally.

## Delegated actions via `action()`

Use `action()` to consolidate button clicks and input/select changes within a container. Instead of binding individual handlers to each element, declare a handler map on the container and let the system dispatch by action name.

### How it works

1. Call `action(handlers)` on a container's partsAPI
2. The system sets up delegated listeners for `click`, `change`, and `input`
3. When an event fires, it finds the closest matching element and resolves an action name via: `data-action` → `value` → `name` (first truthy wins)
4. If a handler exists for that name, it's called with `($target, ev)`

### HTML: mark elements with `data-action`

Buttons use `data-action` (or `value` for buttons whose value already serves as an identifier). Inputs/selects use `data-action` or `name`.

```html
<aside data-part="sidebar" data-mode="detail">
	<button data-action="back">Back</button>
	<button data-action="completed">Complete</button>
	<button data-action="cancelled">Cancel</button>
	<input type="time" data-part="booking-time" data-action="time">
	<select data-part="duration" data-action="duration">...</select>
</aside>
```

### JavaScript: declare handlers on the container

```javascript
$sidebar.action({
	back: () => exitDetailView(),
	completed: () => updateReservationStatus('completed'),
	cancelled: () => updateReservationStatus('cancelled'),
	time: () => loadSlotTables(),
	duration: () => loadSlotTables(),
})
```

### When to use `action()` vs `.on()`

- **Use `action()`** when a container has multiple buttons/inputs that represent discrete operations — especially dialogs, toolbars, and panels
- **Use `.on()`** for single-element handlers, non-delegatable events (mouseenter, pointerdown), or when the handler needs the partsAPI of the listener element itself

### Additive calls

Multiple `action()` calls on the same container merge handlers:

```javascript
$panel.action({ save: () => save() })
// Later...
$panel.action({ delete: () => remove() })
// Both 'save' and 'delete' are now active
```

### Shared action names for same handler

Multiple elements can share the same `data-action` value to trigger a single handler:

```html
<button class="close" data-action="close">×</button>
<!-- ... -->
<button data-action="close">Cancel</button>
```

```javascript
$dialog.action({ close: () => $dialog.modal(false) })
```
