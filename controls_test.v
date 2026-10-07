module vbrowser_contracts

fn test_rank_page_controls_prefers_exact_label_and_skips_disabled() {
	controls := [
		PageControl{id: 'a', role: 'button', label: 'Settings'},
		PageControl{id: 'b', role: 'button', label: 'Advanced Settings'},
		PageControl{id: 'c', role: 'button', label: 'Settings', disabled: true},
	]
	matches := rank_page_controls(controls, 'Settings', ['button'])
	assert matches.len == 2
	assert matches[0].control.id == 'a'
	assert matches[0].score > matches[1].score
}

fn test_rank_page_controls_filters_roles_and_helpers() {
	controls := [
		PageControl{id: 'q', role: 'searchbox', label: 'Search', selector: '#q'},
		PageControl{id: 'go', role: 'button', label: 'Go', selector: '#go'},
		PageControl{id: 'docs', role: 'link', label: 'Docs', href: 'https://example.com/docs'},
	]
	editable := rank_page_controls(controls, '', ['searchbox', 'textbox'])
	assert editable.len == 1
	assert editable[0].control.id == 'q'
	assert page_control_is_editable(controls[0])
	assert page_control_is_clickable(controls[1])
	assert page_control_is_navigable(controls[2])
	found := page_control_by_id(controls, 'go') or { panic('missing control') }
	assert found.selector == '#go'
}
