module vbrowser_contracts

import vaction_contracts

pub const contract_version = '1.0.0'

pub enum IntentKind {
	navigate
	search
	command
	goal
}

pub enum EngineHint {
	auto
	native
	webview
}

pub enum Actor {
	user
	agent
	system
}

pub enum ActionPhase {
	proposed
	awaiting_confirmation
	running
	succeeded
	failed
	cancelled
}

pub struct BrowserTarget {
pub:
	session_id string
	tab_id     string
	frame_id   string
	url        string
}

pub struct BrowserIntent {
pub:
	id          string
	raw         string
	kind        IntentKind
	value       string
	engine_hint EngineHint = .auto
	dry_run     bool
}

pub struct PageSnapshot {
pub:
	session_id       string
	tab_id           string
	revision         u64
	url              string
	title            string
	visible_text     string
	dom_fingerprint  string
	captured_at_unix i64
}

pub struct BrowserAction {
pub:
	id                         string
	intent_id                  string
	name                       string
	args                       map[string]string
	target                     BrowserTarget
	contract                   vaction_contracts.ActionContract
	expected_snapshot_revision u64
	actor                      Actor = .agent
}

pub struct ActionEvidence {
pub:
	action_id       string
	phase           ActionPhase
	summary         string
	source_refs     []string
	before_revision u64
	after_revision  u64
}

pub struct BrowserHandoff {
pub:
	version     string = contract_version
	source      string
	destination string
	session_id  string
	intent      BrowserIntent
	snapshot    PageSnapshot
	pending     []BrowserAction
	evidence    []ActionEvidence
}

pub fn (intent BrowserIntent) valid() bool {
	return intent.raw.trim_space() != '' && intent.value.trim_space() != ''
}

pub fn (action BrowserAction) valid() bool {
	return action.id.trim_space() != '' && action.name.trim_space() != ''
		&& action.contract.valid()
}

pub fn version_compatible(version string) bool {
	current_major := contract_version.all_before('.')
	candidate := version.trim_space()
	if candidate == '' {
		return false
	}
	candidate_major := candidate.all_before('.')
	return candidate_major == current_major
}

pub fn (handoff BrowserHandoff) compatible() bool {
	return version_compatible(handoff.version) && handoff.source.trim_space() != ''
		&& handoff.destination.trim_space() != ''
}

pub fn action_for_intent(id string, intent BrowserIntent, name string, args map[string]string,
	target BrowserTarget, revision u64) BrowserAction {
	return BrowserAction{
		id:                         id
		intent_id:                  intent.id
		name:                       name
		args:                       args.clone()
		target:                     target
		contract:                   vaction_contracts.contract_for_action(name)
		expected_snapshot_revision: revision
	}
}
