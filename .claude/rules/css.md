# CSS rules

This document outlines CSS rules.

## Indentation

**ALWAYS use tabs for indentation. Never use spaces.**

## Units

**Never use `px` units.** Use `em`, `rem`, or relative units instead. The only exception is in JavaScript when matching computed pixel-based metrics from the browser, but that's a different use case.

## Media queries

**Do not use screen-based breakpoints** (e.g., `max-width: 768px`). Instead, use media queries based on the content and layout needs. Breakpoints should be determined by when the design breaks, not by device categories.

Example of what NOT to do:
```css
/* Bad: arbitrary screen-based breakpoint */
@media (max-width: 768px) { ... }
```

Example of content-based approach:
```css
/* Good: based on when sidebar no longer fits */
@media (max-width: 50em) { ... }
```

## Selectors

- **Do not use `data-part` attributes** as selectors. These are reserved for JavaScript.
- Use `id` for unique elements, `class` for repeatable elements
- Use scoped selectors when targeting children (e.g., `#sidebar .link`)

## Tab/state visibility via data attributes

When content sections are toggled by tabs or states, use `:not()` selectors on the container's data attribute:

```css
#container:not([data-tab="foo"]) #section-foo,
#container:not([data-tab="bar"]) #section-bar {
	display: none;
}
```

This pattern:
- Keeps visibility logic in CSS where presentation belongs
- Allows JavaScript to simply set `data-tab="value"` on the container
- Makes it easy to add new tabs without changing JS
