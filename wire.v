module vbrowser_contracts

import json

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

struct WireHeading {
pub:
	level int
	text string
}

struct WireLink {
pub:
	text string
	href string
}

struct WireImage {
pub:
	alt string
	src string
}

struct WireTable {
pub:
	caption string
	headers []string
	row_count int
	column_count int
}

struct WireStructure {
pub:
	description string
	language string
	canonical_url string
	headings []WireHeading
	links []WireLink
	images []WireImage
	tables []WireTable
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
	structure WireStructure
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
	confirmation_granted bool
	confirmation_source string
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
			confirmation_granted: action.confirmation_granted
			confirmation_source: action.confirmation_source
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
	mut headings := []WireHeading{cap: handoff.snapshot.structure.headings.len}
	for item in handoff.snapshot.structure.headings {
		headings << WireHeading{level: item.level, text: item.text}
	}
	mut links := []WireLink{cap: handoff.snapshot.structure.links.len}
	for item in handoff.snapshot.structure.links {
		links << WireLink{text: item.text, href: item.href}
	}
	mut images := []WireImage{cap: handoff.snapshot.structure.images.len}
	for item in handoff.snapshot.structure.images {
		images << WireImage{alt: item.alt, src: item.src}
	}
	mut tables := []WireTable{cap: handoff.snapshot.structure.tables.len}
	for item in handoff.snapshot.structure.tables {
		tables << WireTable{
			caption: item.caption
			headers: item.headers.clone()
			row_count: item.row_count
			column_count: item.column_count
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
			structure: WireStructure{
				description: handoff.snapshot.structure.description
				language: handoff.snapshot.structure.language
				canonical_url: handoff.snapshot.structure.canonical_url
				headings: headings
				links: links
				images: images
				tables: tables
			}
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
	mut headings := []PageHeading{cap: wire.snapshot.structure.headings.len}
	for item in wire.snapshot.structure.headings {
		headings << PageHeading{level: item.level, text: item.text}
	}
	mut links := []PageLink{cap: wire.snapshot.structure.links.len}
	for item in wire.snapshot.structure.links {
		links << PageLink{text: item.text, href: item.href}
	}
	mut images := []PageImage{cap: wire.snapshot.structure.images.len}
	for item in wire.snapshot.structure.images {
		images << PageImage{alt: item.alt, src: item.src}
	}
	mut tables := []PageTable{cap: wire.snapshot.structure.tables.len}
	for item in wire.snapshot.structure.tables {
		tables << PageTable{
			caption: item.caption
			headers: item.headers.clone()
			row_count: item.row_count
			column_count: item.column_count
		}
	}
	mut actions := []BrowserAction{cap: wire.pending.len}
	for item in wire.pending {
		contract := browser_contract_for_action(item.name, item.args)
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
			confirmation_granted: item.confirmation_granted
			confirmation_source: item.confirmation_source
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
			structure: PageStructure{
				description: wire.snapshot.structure.description
				language: wire.snapshot.structure.language
				canonical_url: wire.snapshot.structure.canonical_url
				headings: headings
				links: links
				images: images
				tables: tables
			}
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
