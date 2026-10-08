module vbrowser_contracts

fn test_classify_input() {
	url := classify_input('1', 'example.com')
	assert url.kind == .navigate
	assert url.value == 'https://example.com'

	command := classify_input('2', '/new-tab')
	assert command.kind == .command
	assert command.value == 'new-tab'

	goal := classify_input('3', 'compare these two products')
	assert goal.kind == .goal

	search := classify_input('4', 'v language memory model')
	assert search.kind == .search
}

fn test_handoff_version_gate() {
	handoff := BrowserHandoff{
		source:      'extractor'
		destination: 'browser'
	}
	assert handoff.compatible()
}


fn test_handoff_json_round_trip() {
	handoff := BrowserHandoff{
		source: 'extractor'
		destination: 'browser_runtime'
		intent: BrowserIntent{
			id: 'i1'
			raw: 'example.com'
			kind: .navigate
			value: 'https://example.com'
		}
	}
	payload := encode_handoff(handoff)
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.compatible()
	assert decoded.source == 'extractor'
	assert decoded.intent.kind == .navigate
	assert decoded.intent.value == 'https://example.com'
}


fn test_handoff_accepts_compatible_minor_versions() {
	assert version_compatible('1.0.1')
	assert version_compatible('1.9.7')
	assert !version_compatible('2.0.0')
}

fn test_wire_tolerates_future_minor_enum_values() {
	payload := '{"version":"1.1.0","source":"future","destination":"browser","session_id":"","intent":{"id":"i","raw":"do future thing","kind":"future_goal","value":"do future thing","engine_hint":"future_engine","dry_run":false},"snapshot":{"session_id":"","tab_id":"","revision":0,"url":"","title":"","visible_text":"","dom_fingerprint":"","captured_at_unix":0},"pending":[],"evidence":[]}'
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.compatible()
	assert decoded.intent.kind == .goal
	assert decoded.intent.engine_hint == .auto
}


fn test_browser_operation_vocabulary_is_canonical_and_compatible() {
	assert contract_version == '1.6.0'
	assert normalize_browser_operation('tap') == 'click'
	assert normalize_browser_operation('click by text') == 'click_text'
	assert normalize_browser_operation('select-option') == 'select_value'
	assert normalize_browser_operation('return') == 'press_enter'
	assert browser_operation_supported('fill')
	assert !browser_operation_supported('drag_and_drop')
	assert browser_operation_is_textual('clicktext')
	assert browser_operation_is_mutating('choose')
}

fn test_browser_action_operation_defaults_by_action_kind() {
	intent := BrowserIntent{
		id: 'op'
		raw: 'act'
		kind: .command
		value: 'act'
	}
	act := action_for_intent('a', intent, 'Browser.Act', map[string]string{},
		BrowserTarget{}, 0)
	submit := action_for_intent('s', intent, 'Browser.Submit', map[string]string{},
		BrowserTarget{}, 0)
	assert browser_action_operation(act) == 'click'
	assert browser_action_operation(submit) == 'submit'
}


fn test_handoff_roundtrip_preserves_action_surface_controls() {
	handoff := BrowserHandoff{
		source: 'hebrowser'
		destination: 'waibav'
		snapshot: PageSnapshot{
			revision: 12
			url: 'https://example.com'
			controls: [
				PageControl{
					id: 'el-1'
					role: 'button'
					label: 'Save'
					name: 'save'
					value: ''
					href: ''
					disabled: false
				},
			]
		}
	}
	payload := encode_handoff(handoff)
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.snapshot.controls.len == 1
	assert decoded.snapshot.controls[0].id == 'el-1'
	assert decoded.snapshot.controls[0].role == 'button'
	assert decoded.snapshot.controls[0].label == 'Save'
}


fn test_handoff_roundtrip_preserves_page_structure() {
	handoff := BrowserHandoff{
		source: 'hebrowser'
		destination: 'vimport'
		snapshot: PageSnapshot{
			revision: 21
			url: 'https://example.com/docs'
			title: 'Docs'
			structure: PageStructure{
				description: 'Reference docs'
				language: 'en'
				canonical_url: 'https://example.com/docs'
				headings: [
					PageHeading{level: 1, text: 'Overview'},
					PageHeading{level: 2, text: 'API'},
				]
				links: [
					PageLink{text: 'Guide', href: 'https://example.com/guide'},
				]
				images: [
					PageImage{alt: 'Diagram', src: 'https://example.com/diagram.png'},
				]
				tables: [
					PageTable{
						caption: 'Methods'
						headers: ['Name', 'Meaning']
						row_count: 3
						column_count: 2
					},
				]
			}
		}
	}
	payload := encode_handoff(handoff)
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.snapshot.structure.description == 'Reference docs'
	assert decoded.snapshot.structure.language == 'en'
	assert decoded.snapshot.structure.canonical_url == 'https://example.com/docs'
	assert decoded.snapshot.structure.headings.len == 2
	assert decoded.snapshot.structure.headings[1].text == 'API'
	assert decoded.snapshot.structure.links[0].href == 'https://example.com/guide'
	assert decoded.snapshot.structure.images[0].alt == 'Diagram'
	assert decoded.snapshot.structure.tables[0].headers == ['Name', 'Meaning']
	assert decoded.snapshot.structure.tables[0].row_count == 3
}


fn test_browser_action_contract_escalates_submit_and_external_side_effects() {
	intent := BrowserIntent{
		id: 'risk'
		raw: 'act'
		kind: .command
		value: 'act'
	}
	submit := action_for_intent('submit-1', intent, 'Browser.Act', {
		'operation': 'submit'
	}, BrowserTarget{}, 0)
	assert submit.contract.risk == .high
	assert submit.contract.confirmation_required()

	star := action_for_intent('star-1', intent, 'Browser.Act', {
		'operation': 'click'
		'site_action': 'github.star'
	}, BrowserTarget{}, 0)
	assert star.contract.risk == .high
	assert star.contract.confirmation_required()

	delete := action_for_intent('delete-1', intent, 'Browser.Act', {
		'operation': 'click_text'
		'text': 'Delete repository'
	}, BrowserTarget{}, 0)
	assert delete.contract.risk == .high
	assert delete.contract.confirmation_required()
}

fn test_browser_action_contract_does_not_overconfirm_local_field_edits() {
	intent := BrowserIntent{
		id: 'local-edit'
		raw: 'fill form'
		kind: .command
		value: 'fill form'
	}
	for operation in ['fill', 'set_value', 'select_value', 'scroll_into_view', 'focus'] {
		action := action_for_intent('a-' + operation, intent, 'Browser.Act', {
			'operation': operation
			'value': 'draft'
		}, BrowserTarget{}, 0)
		assert action.contract.risk == .medium
		assert !action.contract.confirmation_required()
	}
}

fn test_browser_action_external_signal_helper_is_narrow() {
	assert browser_action_has_external_side_effect_signal({'text': 'Send message'})
	assert browser_action_has_external_side_effect_signal({'site_action': 'github.star'})
	assert browser_action_has_external_side_effect_signal({'label': 'Save changes'})
	assert !browser_action_has_external_side_effect_signal({'text': 'Open issues'})
	assert !browser_action_has_external_side_effect_signal({'text': 'Search docs'})
}


fn test_wire_roundtrip_preserves_argument_aware_confirmation_policy() {
	intent := BrowserIntent{
		id: 'wire-risk'
		raw: 'star repository'
		kind: .command
		value: 'star repository'
	}
	action := action_for_intent('star-wire', intent, 'Browser.Act', {
		'operation': 'click'
		'site_action': 'github.star'
	}, BrowserTarget{url: 'https://github.com/example/repo'}, 4)
	assert action.contract.confirmation_required()
	payload := encode_handoff(BrowserHandoff{
		source: 'waibav'
		destination: 'browser_runtime'
		intent: intent
		pending: [action]
	})
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.pending.len == 1
	assert decoded.pending[0].contract.risk == .high
	assert decoded.pending[0].contract.confirmation_required()
	assert decoded.pending[0].contract.action == 'Browser.Act'
}


fn test_press_enter_escalates_only_when_context_signals_external_effect() {
	intent := BrowserIntent{
		id: 'enter-risk'
		raw: 'press enter'
		kind: .command
		value: 'press enter'
	}
	send := action_for_intent('send-enter', intent, 'Browser.Act', {
		'operation': 'press_enter'
		'label': 'Send message'
	}, BrowserTarget{}, 0)
	assert send.contract.risk == .high
	assert send.contract.confirmation_required()

	search := action_for_intent('search-enter', intent, 'Browser.Act', {
		'operation': 'press_enter'
		'label': 'Search'
	}, BrowserTarget{}, 0)
	assert search.contract.risk == .medium
	assert !search.contract.confirmation_required()
}


fn test_action_confirmation_is_bound_to_action_and_survives_wire() {
	intent := BrowserIntent{
		id: 'approval'
		raw: 'delete repository'
		kind: .command
		value: 'delete repository'
	}
	action := action_for_intent('delete-approved', intent, 'Browser.Act', {
		'operation': 'click_text'
		'text': 'Delete repository'
	}, BrowserTarget{url: 'https://example.com/admin'}, 6)
	assert action.confirmation_pending()
	approved := grant_action_confirmation(action, 'waibav:user')
	assert !approved.confirmation_pending()
	assert approved.confirmation_granted
	assert approved.confirmation_source == 'waibav:user'
	assert approved.valid()

	payload := encode_handoff(BrowserHandoff{
		source: 'waibav'
		destination: 'browser_runtime'
		intent: intent
		pending: [approved]
	})
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.pending.len == 1
	assert decoded.pending[0].confirmation_granted
	assert decoded.pending[0].confirmation_source == 'waibav:user'
	assert !decoded.pending[0].confirmation_pending()
}

fn test_granted_confirmation_requires_a_source_for_valid_manual_actions() {
	base := BrowserAction{
		id: 'manual'
		name: 'Browser.Act'
		contract: browser_contract_for_action('Browser.Act', {
			'text': 'Delete repository'
		})
		confirmation_granted: true
	}
	assert !base.valid()
	assert grant_action_confirmation(BrowserAction{
		...base
		confirmation_granted: false
	}, 'user').valid()
}


fn test_handoff_roundtrip_preserves_download_artifacts() {
	handoff := BrowserHandoff{
		source: 'hebrowser'
		destination: 'vimport'
		snapshot: PageSnapshot{
			revision: 31
			url: 'https://example.com/report.pdf'
			title: 'report.pdf'
			downloads: [
				PageDownload{
					name: 'report.pdf'
					path: 'C:\\Temp\\hebrowser-downloads\\123\\report.pdf'
					url: 'https://example.com/report.pdf'
					content_type: 'application/pdf'
					bytes: 4242
				},
			]
		}
	}
	payload := encode_handoff(handoff)
	decoded := decode_handoff(payload) or { panic(err.msg()) }
	assert decoded.snapshot.downloads.len == 1
	assert decoded.snapshot.downloads[0].name == 'report.pdf'
	assert decoded.snapshot.downloads[0].content_type == 'application/pdf'
	assert decoded.snapshot.downloads[0].bytes == 4242
	assert decoded.snapshot.downloads[0].path.contains('report.pdf')
}
