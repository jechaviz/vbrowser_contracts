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
