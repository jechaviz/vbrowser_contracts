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
