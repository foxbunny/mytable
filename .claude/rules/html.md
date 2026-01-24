# Rules related to HTML

The role of HTML is always to describe content semantics. It is **not** for appearance or behavior (except indirectlyvia browsers' built-in behaviors). 

## Indentation

**ALWAYS use tabs for indentation. Never use spaces.**

## Linking assets

The `<link>` tags for CSS **must** always have a media attribute. By default we use `media="screen"`. If the page should be printable, then we use `media="print"` in a *separate* stylesheet.

The `<link>` tags come right after `<meta>` tags.

The `<script>` tags **must** be in the `<head>` tag. They come right after any `<link>` tags.

Scripts that serve the purpose of various guards, such as `<script async src="chec-login.js">` **must** use the `async` attribute so they start executing as soon as they're fetched. Other scripts use `type="module"` and are coded as ESM. The `async` and `type="module"` attributes come **before** the `src` attribute.

The `<title>` tag comes *after* any `<link>` and `<script>` tags.

## Code reuse

Linked resources are reused using:

- Separate CSS files linked using separate `<link>` tags (not `@import` rules).
- JavaScript imported using the `import` statements.

HTML is reused by fetching HTML fragments from within JavaScript and either injecting it into the page or used as in-memory documents.

## Use of headings

You always use headings at the start of any significant section. Always pay attention to heading levels and make sure they're following the logical order. If a heading should not be visible (e.g., only used by screen readers), give them the `.text-alt` class.

## Avoid ARIA

Avoid ARIA attributes. Assume that if the content is understandable, the user will figure out what they need to do even without special ARIA attributes.

Instead of `aria-label`, use actual text content with the `.text-alt` class to hide it visually while keeping it accessible to screen readers:

```html
<!-- Bad -->
<button aria-label="Close">&times;</button>

<!-- Good -->
<button><x-icon name="close"></x-icon><span class="text-alt">Close</span></button>
```

## ID, classes, and data-part attributes

Elements are given `id`, `class` and `data-part` attribute to facilitate identification in CSS and JavaScript. `id` and `class` are used to label elements for access in CSS, while `data-part` is used exclusively in JavaScript. These markers always describe the **role of the element within the document**, not their behavior or appearance.

- `id="sidebar"` - ok
- `class="note"` - ok
- `data-part="title"` - ok
- `id="small-section" - bad
- `class="highlighted"` - bad
- `class="selected"` - bad
- `data-part="loading"` - bad

## State-related attributes

State of the element is specified using data attribute. Here are some examples:

- `data-loading` (no value)
- `data-selected` (no value)
- `data-direction="up"`
- `data-category="priority"`

These attribute should not prescribe appearance or behavior:

- `data-small`
- `data-yellow`
- `data-on="click"`

## Feature flag

We can use the `hidden` attribute as a 'feature flag' of sorts, to disable regions that are not in use.

## Initially hidden content

Content that should be hidden until some conditions are met (e.g., data is loaded) can be wrapped in a `<template>` tag, and replaced by the rendered content when the conditions are met:

```
<main>
  <template data-part="content">
    <h2>Dashboard</h2>

    ....
  </template>
</main>
```

## Slots in templates

When a template contains regions that will be populated with dynamic lists or variant content, use `<slot name="...">` elements to mark insertion points. During `.render()`, slots are replaced with comment markers that the template rendering system uses.

```html
<template data-part="content">
	<section>
		<h2>Reservations</h2>
		<ul><slot name="reservation-list"></slot></ul>
	</section>
</template>
```

Item templates are separate `<template>` elements identified by `data-name` (matching the slot name). Elements inside use `data-part` as usual for JS access:

```html
<template data-name="reservation-list">
	<li>
		<span data-part="name"></span> —
		<span data-part="time"></span>
	</li>
</template>
```

For variant templates (e.g., pluralization), add `data-variant`:

```html
<template data-name="guest-count" data-variant="one">
	<span><span data-part="count"></span> guest</span>
</template>
<template data-name="guest-count" data-variant="other">
	<span><span data-part="count"></span> guests</span>
</template>
```

The distinction: `data-part` is for elements accessed via `part()` in JS. `data-name` identifies templates used by the slot rendering system.

## Labels and inputs

Unless there's a very good reason not to, **always wrap inputs in their label**. For styling purposes, wrap the label text in a `<span>`.

```
<label>
  <span>Confirm password</span>
  <input type="password" id="confirm" name="confirm" data-part="confirm" required>
</label>
```

or

```
<label>
    <input type="checkbox" name="sesstype" value="extended">
    <span>Keep me logged in</span>
</label>
```

## Icons

Icons are SVG symbols defined in `public/icons.svg` and used via the `<x-icon name="...">` custom element. When adding a new icon, add both the `<symbol>` to `icons.svg` and a row to the icons table in `public/design-system.html` so all icons remain visible and testable in one place.
