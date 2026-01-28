import { api, $, $$, renderList, showToast, delegate } from './common.js'

let uploadFloorplanImage = (file) => {
	let formData = new FormData()
	formData.append('file', file)
	return fetch('/api/upload-floorplan-image', {
		method: 'POST',
		body: formData,
	}).then(r => { if (!r.ok) return Promise.reject(); return r.json() })
}

let getImageDimensions = (file) => new Promise((resolve, reject) => {
	let img = new Image()
	let url = URL.createObjectURL(file)
	img.onload = () => {
		URL.revokeObjectURL(url)
		resolve({width: img.naturalWidth, height: img.naturalHeight})
	}
	img.onerror = () => {
		URL.revokeObjectURL(url)
		reject(new Error('Failed to load image'))
	}
	img.src = url
})

let statusLoading = $('@status-loading')
let statusError = $('@status-error')
let statusErrorDetail = $('@status-error-detail')
let contentTpl = $('@content')
let floorplanItemTpl = $('@floorplan-item')
let tableEditorDialogTpl = $('@table-editor-dialog')

let floorplans = []
let pendingFloorplan = null

let tableMarkersRecipe = {
	name: (el, v) => $('@marker-label', el).textContent = v,
	x: (el, v) => el.style.setProperty('--x', v),
	y: (el, v) => el.style.setProperty('--y', v),
	tableId: (el, v) => el.dataset.tableId = v,
	selected: (el, v) => el.toggleAttribute('data-selected', v),
}

let openTableEditor = (floorplan) => {
	let editor = tableEditorDialogTpl.content.cloneNode(true).firstElementChild
	let canvasInner = $('@canvas-inner', editor)
	let floorImage = $('@floor-image', editor)
	let hint = $('@hint', editor)
	let tableProps = $('@table-props', editor)
	let propName = $('@prop-name', editor)
	let propCapacity = $('@prop-capacity', editor)
	let propNotes = $('@prop-notes', editor)
	let markersContainer = editor.querySelector('slot[name="table-markers"]')

	// Replace slot with a container div for renderList
	let markersDiv = document.createElement('div')
	markersDiv.className = 'table-markers-list'
	markersContainer.replaceWith(markersDiv)

	let tables = []
	let selectedTableId = null
	let lastCapacity = 4
	let lastNotes = null
	let isDragging = false
	let dragTarget = null
	let dragStartX = 0
	let dragStartY = 0

	$('@dialog-title-name', editor).textContent = floorplan.name
	floorImage.src = floorplan.imagePath

	let renderMarkers = () => {
		let items = tables.map(t => ({
			id: t.id,
			name: t.name,
			x: t.xPct * 100,
			y: t.yPct * 100,
			tableId: t.id,
			selected: t.id == selectedTableId,
		}))
		renderList(markersDiv, items, 'table-markers', tableMarkersRecipe)
	}

	let selectTable = (id) => {
		selectedTableId = id
		let table = tables.find(t => t.id == id)
		if (table) {
			propName.value = table.name
			propCapacity.value = table.capacity
			propNotes.value = table.notes || ''
		}
		tableProps.hidden = !table
		hint.hidden = !!table
		renderMarkers()
	}

	canvasInner.addEventListener('click', ev => {
		if (isDragging) return
		if (ev.target.closest('.table-marker')) return

		let rect = canvasInner.getBoundingClientRect()
		let xPct = (ev.clientX - rect.left) / rect.width
		let yPct = (ev.clientY - rect.top) / rect.height

		api.post('save-floorplan-table', {
			pFloorplanId: floorplan.id,
			pXPct: xPct,
			pYPct: yPct,
			pCapacity: lastCapacity,
			pNotes: lastNotes,
		}).then(t => {
			tables.push({
				id: t.id,
				name: t.name,
				capacity: t.capacity,
				notes: t.notes,
				xPct: t.xPct,
				yPct: t.yPct,
			})
			selectTable(t.id)
		}).catch(() => showToast('Failed to add table'))
	})

	canvasInner.addEventListener('pointerdown', ev => {
		let marker = ev.target.closest('.table-marker')
		if (!marker) return

		ev.preventDefault()
		let id = Number(marker.dataset.tableId)
		selectTable(id)

		isDragging = false
		dragTarget = marker
		dragStartX = ev.clientX
		dragStartY = ev.clientY
	})

	let onPointerMove = ev => {
		if (!dragTarget) return

		let dx = ev.clientX - dragStartX
		let dy = ev.clientY - dragStartY
		if (!isDragging && (Math.abs(dx) > 3 || Math.abs(dy) > 3)) {
			isDragging = true
			dragTarget.dataset.dragging = ''
		}

		if (isDragging) {
			let rect = canvasInner.getBoundingClientRect()
			let xPct = Math.max(0, Math.min(1, (ev.clientX - rect.left) / rect.width))
			let yPct = Math.max(0, Math.min(1, (ev.clientY - rect.top) / rect.height))
			dragTarget.style.setProperty('--x', xPct * 100)
			dragTarget.style.setProperty('--y', yPct * 100)
		}
	}

	let onPointerUp = ev => {
		if (!dragTarget) return

		let marker = dragTarget
		let id = Number(marker.dataset.tableId)
		dragTarget = null

		if (isDragging) {
			delete marker.dataset.dragging
			let rect = canvasInner.getBoundingClientRect()
			let xPct = Math.max(0, Math.min(1, (ev.clientX - rect.left) / rect.width))
			let yPct = Math.max(0, Math.min(1, (ev.clientY - rect.top) / rect.height))

			api.post('update-floorplan-table', {pId: id, pXPct: xPct, pYPct: yPct}).then(r => {
				let table = tables.find(t => t.id == id)
				if (table) {
					table.xPct = r.xPct
					table.yPct = r.yPct
				}
				renderMarkers()
			}).catch(() => {
				renderMarkers()
				showToast('Failed to move table')
			})
		}
		isDragging = false
	}

	document.addEventListener('pointermove', onPointerMove)
	document.addEventListener('pointerup', onPointerUp)

	let updateSelectedTable = () => {
		if (!selectedTableId) return
		let name = propName.value.trim()
		let capacity = Number(propCapacity.value) || 4
		let notes = propNotes.value.trim() || null

		lastCapacity = capacity
		lastNotes = notes

		api.post('update-floorplan-table', {
			pId: selectedTableId,
			pName: name || null,
			pCapacity: capacity,
			pNotes: notes,
		}).then(r => {
			let table = tables.find(t => t.id == selectedTableId)
			if (table) {
				table.name = r.name
				table.capacity = r.capacity
				table.notes = r.notes
			}
			renderMarkers()
		}).catch(() => showToast('Failed to update table'))
	}

	// Delegated action handler
	editor.addEventListener('click', delegate('[data-action]', (ev, btn) => {
		let action = btn.dataset.action
		if (action == 'update-table') {
			updateSelectedTable()
		} else if (action == 'delete-table') {
			if (!selectedTableId) return
			let id = selectedTableId
			api.post('delete-floorplan-table', {pId: id}).then(() => {
				tables = tables.filter(t => t.id != id)
				selectTable(null)
			}).catch(() => showToast('Failed to delete table'))
		} else if (action == 'close') {
			editor.close()
		}
	}))

	// Handle input changes for update-table
	editor.addEventListener('change', delegate('[data-action="update-table"]', updateSelectedTable))

	editor.addEventListener('close', () => {
		document.removeEventListener('pointermove', onPointerMove)
		document.removeEventListener('pointerup', onPointerUp)
		editor.remove()
	})

	document.body.appendChild(editor)
	api.get('get-floorplan-tables', {pFloorplanId: floorplan.id}).then(result => {
		tables = result || []
		renderMarkers()
		editor.showModal()
	}).catch(() => showToast('Failed to load tables'))
}

Promise.all([api.get('get-restaurant'), api.get('get-floorplans')])
	.then(([restaurants, fps]) => {
		let restaurant = restaurants[0] || null
		floorplans = fps || []

		let rendered = contentTpl.content.cloneNode(true).firstElementChild
		contentTpl.replaceWith(rendered)
		statusLoading.hidden = true

		let form = $('@form', rendered)
		let nameInput = $('@name', rendered)
		let addressInput = $('@address', rendered)
		let phoneInput = $('@phone', rendered)
		let msgApiText = $('@msg-api-text', rendered)
		let submit = $('@submit', rendered)

		let floorplanSection = rendered.querySelector('#floorplans-section')
		let floorplanList = $('@floorplan-list', rendered)
		let addFloorplanForm = $('@add-floorplan-form', rendered)
		let floorplanNameInput = $('@floorplan-name', rendered)
		let floorplanFileInput = $('@floorplan-file', rendered)
		let floorplanPreview = $('@floorplan-preview', rendered)
		let previewImage = $('@preview-image', rendered)
		let previewDimensions = $('@preview-dimensions', rendered)
		let saveFloorplanBtn = $('@save-floorplan', rendered)

		if (restaurant) {
			nameInput.value = restaurant.name || ''
			addressInput.value = restaurant.address || ''
			phoneInput.value = restaurant.phone || ''

			if (restaurant.workingHours) {
				let days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
				days.forEach(day => {
					let row = rendered.querySelector(`[data-day="${day}"]`)
					let checkbox = row.querySelector('[data-part="day-enabled"]')
					let openInput = row.querySelector('[data-part="day-open"]')
					let closeInput = row.querySelector('[data-part="day-close"]')
					let hours = restaurant.workingHours[day]

					if (hours) {
						checkbox.checked = true
						openInput.value = hours.open || '11:00'
						closeInput.value = hours.close || '22:00'
						row.dataset.enabled = ''
					}
				})
			}
		}

		let renderFloorplans = () => {
			floorplanList.innerHTML = ''
			floorplans.forEach(fp => {
				let item = floorplanItemTpl.content.cloneNode(true).firstElementChild
				item.dataset.fpId = fp.id
				$('@thumb', item).src = fp.imagePath
				$('@fp-name', item).textContent = fp.name
				$('@fp-dimensions', item).textContent = `${fp.imageWidth} x ${fp.imageHeight}px`
				floorplanList.appendChild(item)
			})
		}
		renderFloorplans()

		let dayRows = rendered.querySelectorAll('.day-row')
		dayRows.forEach(row => {
			let checkbox = row.querySelector('[data-part="day-enabled"]')
			checkbox.addEventListener('change', () => {
				if (checkbox.checked)
					row.dataset.enabled = ''
				else
					delete row.dataset.enabled
			})
		})

		let resetFloorplanForm = () => {
			floorplanNameInput.value = ''
			floorplanFileInput.value = ''
			previewImage.src = ''
			previewDimensions.textContent = ''
			floorplanPreview.hidden = false
			saveFloorplanBtn.disabled = true
			pendingFloorplan = null
		}

		let saveFloorplan = () => {
			if (!pendingFloorplan || !floorplanNameInput.value.trim()) return

			let name = floorplanNameInput.value.trim()
			saveFloorplanBtn.disabled = true
			saveFloorplanBtn.dataset.uploading = true

			uploadFloorplanImage(pendingFloorplan.file)
				.then(uploadResult => api.post('save-floorplan', {
					pName: name,
					pImagePath: uploadResult.path,
					pImageWidth: pendingFloorplan.width,
					pImageHeight: pendingFloorplan.height,
					pSortOrder: floorplans.length,
				}))
				.then(() => api.get('get-floorplans'))
				.then(fps => {
					floorplans = fps
					renderFloorplans()
					addFloorplanForm.hidden = true
					resetFloorplanForm()
					delete saveFloorplanBtn.dataset.uploading
				})
				.catch(() => {
					saveFloorplanBtn.disabled = false
					delete saveFloorplanBtn.dataset.uploading
					showToast('Failed to save floor plan. Please try again.')
				})
		}

		floorplanSection.addEventListener('click', delegate('[data-action]', (ev, btn) => {
			let action = btn.dataset.action
			if (action == 'add-floorplan') {
				addFloorplanForm.hidden = false
				btn.hidden = true
				floorplanNameInput.focus()
			} else if (action == 'cancel-floorplan') {
				addFloorplanForm.hidden = true
				floorplanSection.querySelector('[data-action="add-floorplan"]').hidden = false
				resetFloorplanForm()
			} else if (action == 'save-floorplan') {
				saveFloorplan()
			} else if (action == 'edit-tables') {
				let fpId = Number(btn.closest('[data-fp-id]').dataset.fpId)
				let fp = floorplans.find(f => f.id == fpId)
				if (fp) openTableEditor(fp)
			} else if (action == 'delete-fp') {
				let fpId = Number(btn.closest('[data-fp-id]').dataset.fpId)
				api.post('delete-floorplan', {pId: fpId}).then(() => {
					floorplans = floorplans.filter(f => f.id != fpId)
					renderFloorplans()
				}).catch(() => showToast('Failed to delete floor plan'))
			}
		}))

		floorplanFileInput.addEventListener('change', () => {
			let file = floorplanFileInput.files[0]
			if (!file) {
				floorplanPreview.hidden = false
				saveFloorplanBtn.disabled = true
				pendingFloorplan = null
				return
			}

			getImageDimensions(file).then(dims => {
				pendingFloorplan = {file, width: dims.width, height: dims.height}
				previewImage.src = URL.createObjectURL(file)
				previewDimensions.textContent = `${dims.width} x ${dims.height}px`
				floorplanPreview.hidden = true
				saveFloorplanBtn.disabled = !floorplanNameInput.value.trim()
			}).catch(() => {
				floorplanPreview.hidden = false
				saveFloorplanBtn.disabled = true
				pendingFloorplan = null
			})
		})

		floorplanNameInput.addEventListener('input', () => {
			saveFloorplanBtn.disabled = !floorplanNameInput.value.trim() || !pendingFloorplan
		})

		form.addEventListener('submit', ev => {
			ev.preventDefault()
			let data = Object.fromEntries(new FormData(form))

			let workingHours = {}
			dayRows.forEach(row => {
				let day = row.dataset.day
				let checkbox = row.querySelector('[data-part="day-enabled"]')
				if (checkbox.checked) {
					let openInput = row.querySelector('[data-part="day-open"]')
					let closeInput = row.querySelector('[data-part="day-close"]')
					workingHours[day] = {
						open: openInput.value,
						close: closeInput.value,
					}
				}
			})

			rendered.dataset.state = 'loading'
			submit.disabled = true

			// Client-side validation: check if tables exist
			api.get('has-tables').then(result => {
				if (!result[0]?.hasTables) {
					delete rendered.dataset.state
					submit.disabled = false
					showToast('Please add at least one table to a floor plan before completing setup.')
					return
				}

				return api.post('save-restaurant', {
					pName: data.name.trim(),
					pAddress: data.address?.trim() || null,
					pPhone: data.phone?.trim() || null,
					pWorkingHours: workingHours,
				}).then(result => {
					if (result.error) {
						msgApiText.textContent = result.error.split(': ')[1] || result.error
						rendered.dataset.state = 'error-api'
						submit.disabled = false
					} else {
						rendered.dataset.state = 'success'
						setTimeout(() => {
							window.location.href = 'back-office.html'
						}, 1500)
					}
				})
			}).catch(() => {
				rendered.dataset.state = 'error-network'
				submit.disabled = false
			})
		})
	})
	.catch(err => {
		console.error('Load error:', err)
		statusErrorDetail.textContent = err.message
		statusLoading.hidden = true
		statusError.hidden = false
	})
