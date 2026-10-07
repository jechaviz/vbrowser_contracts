module vbrowser_contracts

import json
import vaction_contracts

struct WireHandoff {
pub:
	version string
	source string
	destination string
	session_id string
	intent WireIntent
	snapshot WireSnapshot
	pending []WireAction
	evidence []WireEvidence
}

struct WireIntent {
pub:
	id string
	raw string
	kind string
	value string
	engine_hint string
	dry_run bool
}

struct WireControl {
pub:
	id string
	role string
	label string
	name string
	value string
	selector string
	href string
	disabled bool
	checked bool
}

struct WireSnapshot {
pub:
	session_id string
	tab_id string
	revision u64
	url string
	title string
	visible_text string
	dom_fingerprint string
	captured_at_unix i64
	controls []WireControl
}

struct WireAction {
pub:
	id string
	intent_id string
	name string
	args map[string]string
	session_id string
	tab_id string
	frame_id string
	url string
	expected_snapshot_revision u64
	actor string
}

struct WireEvidence {
pub:
	action_id string
	phase string
	summary string
	source_refs []string
	before_revision u64
	after_revision u64
}

pub fn encode_handoff(handoff BrowserHandoff) string {
	mut actions := []WireAction{cap: handoff.pending.len}
	for action in handoff.pending {
		actions << WireAction{
			id: action.id
			intent_id: action.intent_id
			name: action.name
			args: action.args.clone()
			session_id: action.target.session_id
			tab_id: action.target.tab_id
			frame_id: action.target.frame_id
			url: action.target.url
			expected_snapshot_revision: action.expected_snapshot_revision
			actor: action.actor.str()
		}
	}
	mut evidence := []WireEvidence{cap: handoff.evidence.len}
	for receipt in handoff.evidence {
		evidence << WireEvidence{
			action_id: receipt.action_id
			phase: receipt.phase.str()
			summary: receipt.summary
			source_refs: receipt.source_refs.clone()
			before_revision: receipt.before_revision
			after_revision: receipt.after_revision
		}
	}
	mut controls := []WireControl{cap: handoff.snapshot.controls.len}
	for control in handoff.snapshot.controls {
		controls << WireControl{
			id: control.id
			role: control.role
			label: control.label
			name: control.name
			value: control.value
			selector: control.selector
			href: control.href
			disabled: control.disabled
			checked: control.checked
		}
	}
	wire := WireHandoff{
		version: handoff.version
		source: handoff.source
		destination: handoff.destination
		session_id: handoff.session_id
		intent: WireIntent{
			id: handoff.intent.id
			raw: handoff.intent.raw
			kind: handoff.intent.kind.str()
			value: handoff.intent.value
			engine_hint: handoff.intent.engine_hint.str()
			dry_run: handoff.intent.dry_run
		}
		snapshot: WireSnapshot{
			session_id: handoff.snapshot.session_id
			tab_id: handoff.snapshot.tab_id
			revision: handoff.snapshot.revision
			url: handoff.snapshot.url
			title: handoff.snapshot.title
			visible_text: handoff.snapshot.visible_text
			dom_fingerprint: handoff.snapshot.dom_fingerprint
			captured_at_unix: handoff.snapshot.captured_at_unix
			controls: controls
		}
		pending: actions
		evidence: evidence
	}
	return json.encode(wire)
}

pub fn decode_handoff(payload string) !BrowserHandoff {
	wire := json.decode(WireHandoff, payload)!
	if !version_compatible(wire.version) {
		return error('unsupported browser handoff major version: ${wire.version}')
	}
	intent := BrowserIntent{
		id: wire.intent.id
		raw: wire.intent.raw
		kind: parse_intent_kind(wire.intent.kind)!
		value: wire.intent.value
		engine_hint: parse_engine_hint(wire.intent.engine_hint)!
		dry_run: wire.intent.dry_run
	}
	mut controls := []PageControl{cap: wire.snapshot.controls.len}
	for item in wire.snapshot.controls {
		controls << PageControl{
			id: item.id
			role: item.role
			label: item.label
			name: item.name
			value: item.value
			selector: item.selector
			href: item.href
			disabled: item.disabled
			checked: item.checked
		}
	}
	mut actions := []BrowserAction{cap: wire.pending.len}
	for item in wire.pending {
		contract := vaction_contracts.contract_for_action(item.name)
		actions << BrowserAction{
			id: item.id
			intent_id: item.intent_id
			name: item.name
			args: item.args.clone()
			target: BrowserTarget{
				session_id: item.session_id
				tab_id: item.tab_id
				frame_id: item.frame_id
				url: item.url
			}
			contract: contract
			expected_snapshot_revision: item.expected_snapshot_revision
			actor: parse_actor(item.actor)!
		}
	}
	mut evidence := []ActionEvidence{cap: wire.evidence.len}
	for item in wire.evidence {
		evidence << ActionEvidence{
			action_id: item.action_id
			phase: parse_action_phase(item.phase)!
			summary: item.summary
			source_refs: item.source_refs.clone()
			before_revision: item.before_revision
			after_revision: item.after_revision
		}
	}
	return BrowserHandoff{
		version: wire.version
		source: wire.source
		destination: wire.destination
		session_id: wire.session_id
		intent: intent
		snapshot: PageSnapshot{
			session_id: wire.snapshot.session_id
			tab_id: wire.snapshot.tab_id
			revision: wire.snapshot.revision
			url: wire.snapshot.url
			title: wire.snapshot.title
			visible_text: wire.snapshot.visible_text
			dom_fingerprint: wire.snapshot.dom_fingerprint
			captured_at_unix: wire.snapshot.captured_at_unix
			controls: controls
		}
		pending: actions
		evidence: evidence
	}
}

fn parse_intent_kind(value string) !IntentKind {
	return match value {
		'navigate' { .navigate }
		'search' { .search }
		'command' { .command }
		'goal' { .goal }
		else { .goal }
	}
}

fn parse_engine_hint(value string) !EngineHint {
	return match value {
		'', 'auto' { .auto }
		'native' { .native }
		'webview' { .webview }
		else { .auto }
	}
}

fn parse_actor(value string) !Actor {
	return match value {
		'', 'agent' { .agent }
		'user' { .user }
		'system' { .system }
		else { .agent }
	}
}

fn parse_action_phase(value string) !ActionPhase {
	return match value {
		'proposed' { .proposed }
		'awaiting_confirmation' { .awaiting_confirmation }
		'running' { .running }
		'succeeded' { .succeeded }
		'failed' { .failed }
		'cancelled' { .cancelled }
		else { .proposed }
	}
}
