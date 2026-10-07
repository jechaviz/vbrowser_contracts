module vbrowser_contracts

import json

pub fn encode_handoff(handoff BrowserHandoff) string {
	return json.encode(handoff)
}

pub fn decode_handoff(payload string) !BrowserHandoff {
	handoff := json.decode(BrowserHandoff, payload)!
	if !handoff.compatible() {
		return error('incompatible browser handoff contract: ${handoff.version}')
	}
	return handoff
}
