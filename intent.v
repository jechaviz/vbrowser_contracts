module vbrowser_contracts

pub fn classify_input(id string, raw string) BrowserIntent {
	clean := raw.trim_space()
	if clean == '' {
		return BrowserIntent{
			id:    id
			raw:   raw
			kind:  .search
			value: ''
		}
	}
	if clean.starts_with('/') || clean.starts_with('>') {
		return BrowserIntent{
			id:    id
			raw:   raw
			kind:  .command
			value: clean.trim_left('/>').trim_space()
		}
	}
	if looks_like_url(clean) {
		return BrowserIntent{
			id:    id
			raw:   raw
			kind:  .navigate
			value: normalize_url(clean)
		}
	}
	if looks_like_goal(clean) {
		return BrowserIntent{
			id:    id
			raw:   raw
			kind:  .goal
			value: clean
		}
	}
	return BrowserIntent{
		id:    id
		raw:   raw
		kind:  .search
		value: clean
	}
}

pub fn looks_like_url(value string) bool {
	clean := value.trim_space().to_lower()
	if clean.contains(' ') {
		return false
	}
	return clean.starts_with('http://') || clean.starts_with('https://')
		|| clean.starts_with('file://') || clean.starts_with('about:')
		|| clean.starts_with('www.') || (clean.contains('.') && clean.len > 3)
}

pub fn normalize_url(value string) string {
	clean := value.trim_space()
	if clean.starts_with('http://') || clean.starts_with('https://') || clean.starts_with('file://')
		|| clean.starts_with('about:') {
		return clean
	}
	return 'https://${clean}'
}

fn looks_like_goal(value string) bool {
	low := value.to_lower()
	for prefix in ['find ', 'open ', 'compare ', 'summarize ', 'research ', 'book ', 'buy ',
		'download ', 'fill ', 'send ', 'create ', 'check ', 'go to ', 'busca ', 'abre ',
		'compara ', 'resume ', 'investiga ', 'descarga ', 'llena ', 'envia ', 'crea ', 'revisa '] {
		if low.starts_with(prefix) {
			return true
		}
	}
	return false
}
