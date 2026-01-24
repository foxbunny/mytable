import { api, part, registerTemplate } from './common.js'

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

let $statusLoading = part('status-loading')
let $statusError = part('status-error')
let $statusErrorDetail = part('status-error-detail')
let content = part('content')
let floorplanItemTemplate = part('floorplan-item')
let tableEditorDialogTemplate = part('table-editor-dialog')
let toastTpl = part('toast-template')
let $toastList = document.getElementById('toast-list')

let showToast = (message) => {
	let toast = toastTpl.render()
	toast.part('toast-message').text(message)
	toast.part('toast-dismiss').on('click', () => {
		toast.data('clear', '')
		setTimeout(() => toast.remove(), 300)
	})
	toast.on('animationend', ev => {
		if (ev.animationName == 'expire') {
			toast.data('clear', '')
			setTimeout(() => toast.remove(), 300)
		}
	})
	toast.each(el => $toastList.appendChild(el))
}

let floorplans = []
let pendingFloorplan = null

registerTemplate('table-markers', {
	name: ($, v) => $.part('marker-label').text(v),
	x: ($, v) => $.cssProp('--x', v),
	y: ($, v) => $.cssProp('--y', v),
	tableId: ($, v) => $.data('tableId', v),
	selected: ($, v) => $.data('selected', v || false),
})

let openTableEditor = (floorplan) => {
	let editor = tableEditorDialogTemplate.render()
	let canvasInner = editor.part('canvas-inner')
	let floorImage = editor.part('floor-image')
	let hint = editor.part('hint')
	let tableProps = editor.part('table-props')
	let propName = editor.part('prop-name')
	let propCapacity = editor.part('prop-capacity')
	let propNotes = editor.part('prop-notes')

	let tables = []
	let selectedTableId = null
	let lastCapacity = 4
	let lastNotes = null
	let isDragging = false
	let dragTarget = null
	let dragStartX = 0
	let dragStartY = 0

	editor.part('dialog-title-name').text(floorplan.name)
	floorImage.src(floorplan.imagePath)

	let renderMarkers = () => {
		let items = tables.map(t => ({
			id: t.id,
			name: t.name,
			x: t.xPct * 100,
			y: t.yPct * 100,
			tableId: t.id,
			selected: t.id == selectedTableId,
		}))
		editor.renderFromTemplate('table-markers', items)
	}

	let selectTable = (id) => {
		selectedTableId = id
		let table = tables.find(t => t.id == id)
		if (table) {
			propName.val(table.name)
			propCapacity.val(table.capacity)
			propNotes.val(table.notes || '')
		}
		tableProps.shown(!!table)
		hint.hidden(!!table)
		renderMarkers()
	}

	canvasInner.on('click', ev => {
		if (isDragging) return
		if (ev.target.closest('.table-marker')) return

		let rect = canvasInner.meth('getBoundingClientRect')
		let xPct = (ev.clientX - rect.left) / rect.width
		let yPct = (ev.clientY - rect.top) / rect.height

		api.post('save-floorplan-table', {
			pFloorplanId: floorplan.id,
			pXPct: xPct,
			pYPct: yPct,
			pCapacity: lastCapacity,
			pNotes: lastNotes,
		}).then(rows => {
			let t = rows[0]
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

	canvasInner.on('pointerdown', ev => {
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
			let rect = canvasInner.meth('getBoundingClientRect')
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
			let rect = canvasInner.meth('getBoundingClientRect')
			let xPct = Math.max(0, Math.min(1, (ev.clientX - rect.left) / rect.width))
			let yPct = Math.max(0, Math.min(1, (ev.clientY - rect.top) / rect.height))

			api.post('update-floorplan-table', {pId: id, pXPct: xPct, pYPct: yPct}).then(rows => {
				let table = tables.find(t => t.id == id)
				if (table) {
					table.xPct = rows[0].xPct
					table.yPct = rows[0].yPct
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
		let name = propName.val().trim()
		let capacity = Number(propCapacity.val()) || 4
		let notes = propNotes.val().trim() || null

		lastCapacity = capacity
		lastNotes = notes

		api.post('update-floorplan-table', {
			pId: selectedTableId,
			pName: name || null,
			pCapacity: capacity,
			pNotes: notes,
		}).then(rows => {
			let r = rows[0]
			let table = tables.find(t => t.id == selectedTableId)
			if (table) {
				table.name = r.name
				table.capacity = r.capacity
				table.notes = r.notes
			}
			renderMarkers()
		}).catch(() => showToast('Failed to update table'))
	}

	editor.action({
		'update-table': () => updateSelectedTable(),
		'delete-table': () => {
			if (!selectedTableId) return
			let id = selectedTableId
			api.post('delete-floorplan-table', {pId: id}).then(() => {
				tables = tables.filter(t => t.id != id)
				selectTable(null)
			}).catch(() => showToast('Failed to delete table'))
		},
		close: () => editor.modal(false),
	})
	editor.on('close', () => {
		document.removeEventListener('pointermove', onPointerMove)
		document.removeEventListener('pointerup', onPointerUp)
		editor.remove()
	})

	editor.each(el => document.body.appendChild(el))
	api.get('get-floorplan-tables', {pFloorplanId: floorplan.id}).then(result => {
		tables = result || []
		renderMarkers()
		editor.modal()
	}).catch(() => showToast('Failed to load tables'))
}

Promise.all([api.get('get-restaurant'), api.get('get-floorplans')])
	.then(([restaurants, fps]) => {
		let restaurant = restaurants[0] || null
		floorplans = fps || []

		let rendered = content.render()
		content.replaceWith(rendered)
		$statusLoading.hidden()

		let form = rendered.part('form')
		let nameInput = rendered.part('name')
		let addressInput = rendered.part('address')
		let phoneInput = rendered.part('phone')
		let $msgApiText = rendered.part('msg-api-text')
		let submit = rendered.part('submit')

		let floorplanList = rendered.part('floorplan-list')
		let addFloorplanForm = rendered.part('add-floorplan-form')
		let addFloorplanBtn = rendered.part('add-floorplan-btn')
		let floorplanNameInput = rendered.part('floorplan-name')
		let floorplanFileInput = rendered.part('floorplan-file')
		let floorplanPreview = rendered.part('floorplan-preview')
		let previewImage = rendered.part('preview-image')
		let previewDimensions = rendered.part('preview-dimensions')
		let cancelFloorplanBtn = rendered.part('cancel-floorplan')
		let saveFloorplanBtn = rendered.part('save-floorplan')

		if (restaurant) {
			nameInput.val(restaurant.name || '')
			addressInput.val(restaurant.address || '')
			phoneInput.val(restaurant.phone || '')

			if (restaurant.workingHours) {
				let days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
				days.forEach(day => {
					let row = rendered.meth('querySelector', `[data-day="${day}"]`)
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
			floorplanList.empty()
			floorplans.forEach(fp => {
				let item = floorplanItemTemplate.render()
				item.part('thumb').src(fp.imagePath)
				item.part('fp-name').text(fp.name)
				item.part('fp-dimensions').text(`${fp.imageWidth} x ${fp.imageHeight}px`)
				item.part('edit-tables').on('click', () => openTableEditor(fp))
				item.part('delete-fp').on('click', () => {
					api.post('delete-floorplan', {pId: fp.id}).then(() => {
						floorplans = floorplans.filter(f => f.id != fp.id)
						renderFloorplans()
					}).catch(() => showToast('Failed to delete floor plan'))
				})
				floorplanList.append(item)
			})
		}
		renderFloorplans()

		let dayRows = rendered.meth('querySelectorAll', '.day-row')
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
			floorplanNameInput.val('')
			floorplanFileInput.val('')
			previewImage.src('')
			previewDimensions.text('')
			floorplanPreview.shown()
			saveFloorplanBtn.disabled()
			pendingFloorplan = null
		}

		addFloorplanBtn.on('click', () => {
			addFloorplanForm.shown()
			addFloorplanBtn.hidden()
			floorplanNameInput.each(el => el.focus())
		})

		cancelFloorplanBtn.on('click', () => {
			addFloorplanForm.hidden()
			addFloorplanBtn.shown()
			resetFloorplanForm()
		})

		floorplanFileInput.on('change', () => {
			let file = floorplanFileInput.get('files')[0]
			if (!file) {
				floorplanPreview.shown()
				saveFloorplanBtn.disabled()
				pendingFloorplan = null
				return
			}

			getImageDimensions(file).then(dims => {
				pendingFloorplan = {file, width: dims.width, height: dims.height}
				previewImage.src(URL.createObjectURL(file))
				previewDimensions.text(`${dims.width} x ${dims.height}px`)
				floorplanPreview.hidden()
				saveFloorplanBtn.disabled(!floorplanNameInput.val().trim())
			}).catch(() => {
				floorplanPreview.shown()
				saveFloorplanBtn.disabled()
				pendingFloorplan = null
			})
		})

		floorplanNameInput.on('input', () => {
			saveFloorplanBtn.disabled(!floorplanNameInput.val().trim() || !pendingFloorplan)
		})

		saveFloorplanBtn.on('click', () => {
			if (!pendingFloorplan || !floorplanNameInput.val().trim()) return

			let name = floorplanNameInput.val().trim()
			saveFloorplanBtn.disabled()
			saveFloorplanBtn.data('uploading', true)

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
					addFloorplanForm.hidden()
					addFloorplanBtn.shown()
					resetFloorplanForm()
					saveFloorplanBtn.data('uploading', false)
				})
				.catch(() => {
					saveFloorplanBtn.disabled(false)
					saveFloorplanBtn.data('uploading', false)
					showToast('Failed to save floor plan. Please try again.')
				})
		})

		form.submit(data => {
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

			rendered.data('state', 'loading')
			submit.disabled()

			api.post('save-restaurant', {
				pName: data.name.trim(),
				pAddress: data.address?.trim() || null,
				pPhone: data.phone?.trim() || null,
				pWorkingHours: workingHours,
			}).then(result => {
				if (result.error) {
					$msgApiText.text(result.error.split(': ')[1] || result.error)
					rendered.data('state', 'error-api')
					submit.disabled(false)
				} else {
					rendered.data('state', 'success')
					setTimeout(() => {
						window.location.href = 'back-office.html'
					}, 1500)
				}
			}).catch(() => {
				rendered.data('state', 'error-network')
				submit.disabled(false)
			})
		})
	})
	.catch(err => {
		console.error('Load error:', err)
		$statusErrorDetail.text(err.message)
		$statusLoading.hidden()
		$statusError.shown()
	})
