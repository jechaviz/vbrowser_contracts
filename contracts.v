module vbrowser_contracts

import vaction_contracts

pub const contract_version = '1.6.0'

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

pub struct PageControl {
pub:
	id       string
	role     string
	label    string
	name     string
	value    string
	selector string
	href     string
	disabled bool
	checked  bool
}

pub struct PageHeading {
pub:
	level int
	text  string
}

pub struct PageLink {
pub:
	text string
	href string
}

pub struct PageImage {
pub:
	alt string
	src string
}

pub struct PageTable {
pub:
	caption      string
	headers      []string
	row_count    int
	column_count int
}

pub struct PageStructure {
pub:
	description   string
	language      string
	canonical_url string
	headings      []PageHeading
	links         []PageLink
	images        []PageImage
	tables        []PageTable
}

pub struct PageDownload {
pub:
	name         string
	path         string
	url          string
	content_type string
	bytes        i64
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
	controls         []PageControl
	downloads        []PageDownload
	structure        PageStructure
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
	confirmation_granted       bool
	confirmation_source        string
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
		&& (!action.confirmation_granted || action.confirmation_source.trim_space() != '')
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


pub fn (handoff BrowserHandoff) verified_success(state_receipt_id string) bool {
	if !handoff.compatible() || handoff.pending.len > 0 || state_receipt_id.trim_space() == '' {
		return false
	}
	mut state_verified := false
	for receipt in handoff.evidence {
		if receipt.phase in [.failed, .cancelled, .awaiting_confirmation, .running] {
			return false
		}
		if receipt.action_id == state_receipt_id {
			if receipt.phase != .succeeded {
				return false
			}
			state_verified = true
		}
	}
	return state_verified
}

pub fn action_for_intent(id string, intent BrowserIntent, name string, args map[string]string,
	target BrowserTarget, revision u64) BrowserAction {
	return BrowserAction{
		id:                         id
		intent_id:                  intent.id
		name:                       name
		args:                       args.clone()
		target:                     target
		contract:                   browser_contract_for_action(name, args)
		expected_snapshot_revision: revision
	}
}


pub fn (action BrowserAction) confirmation_pending() bool {
	return action.contract.confirmation_required() && !action.confirmation_granted
}

pub fn grant_action_confirmation(action BrowserAction, source string) BrowserAction {
	clean_source := if source.trim_space() != '' { source.trim_space() } else { 'unspecified' }
	return BrowserAction{
		...action
		confirmation_granted: true
		confirmation_source: clean_source
	}
}

pub fn browser_contract_for_action(name string, args map[string]string) vaction_contracts.ActionContract {
	base := vaction_contracts.contract_for_action(name)
	operation := normalize_browser_operation(args['operation'] or {
		if name == 'Browser.Submit' { 'submit' } else { 'click' }
	})
	if name == 'Browser.Submit' || operation == 'submit' {
		submit := vaction_contracts.contract_for_action('Browser.Submit')
		return vaction_contracts.ActionContract{
			...submit
			action: name
		}
	}
	if name == 'Browser.Act' && browser_action_has_external_side_effect_signal(args) {
		mut effects := base.effects.clone()
		if .network !in effects {
			effects << .network
		}
		mut evidence := base.evidence.clone()
		if 'confirmation_receipt' !in evidence {
			evidence << 'confirmation_receipt'
		}
		return vaction_contracts.ActionContract{
			...base
			risk: .high
			effects: effects
			evidence: evidence
			requires_confirmation: true
		}
	}
	return base
}

pub fn browser_action_has_external_side_effect_signal(args map[string]string) bool {
	mut signal := []string{}
	for key in ['site_action', 'text', 'label', 'aria_label', 'title', 'description', 'goal'] {
		value := args[key] or { '' }
		if value.trim_space() != '' {
			signal << value.to_lower()
		}
	}
	joined := signal.join(' ')
	for marker in [
		'delete', 'remove', 'destroy', 'erase',
		'send', 'message', 'post', 'publish',
		'buy', 'purchase', 'checkout', 'pay', 'order',
		'approve', 'accept', 'merge', 'close issue', 'close pull',
		'star', 'unstar', 'follow', 'unfollow', 'like', 'unlike',
		'subscribe', 'unsubscribe', 'invite', 'connect',
		'upload', 'create', 'save changes',
	] {
		if joined.contains(marker) {
			return true
		}
	}
	return false
}

pub const browser_operations = [
	'click',
	'click_text',
	'fill',
	'fill_text',
	'set_value',
	'submit',
	'check',
	'uncheck',
	'toggle',
	'select_value',
	'focus',
	'press_enter',
	'scroll_into_view',
]

pub fn normalize_browser_operation(value string) string {
	clean := value.trim_space().to_lower().replace('-', '_').replace(' ', '_')
	return match clean {
		'', 'activate', 'press', 'tap' { 'click' }
		'click_by_text', 'clicktext' { 'click_text' }
		'type', 'input', 'set', 'setvalue' { 'set_value' }
		'fill_by_text', 'filltext' { 'fill_text' }
		'select', 'select_option', 'choose', 'choose_option' { 'select_value' }
		'enter', 'return', 'pressenter' { 'press_enter' }
		'scroll_to', 'reveal', 'scrollintoview' { 'scroll_into_view' }
		else { clean }
	}
}

pub fn browser_operation_supported(value string) bool {
	return normalize_browser_operation(value) in browser_operations
}

pub fn browser_action_operation(action BrowserAction) string {
	fallback := if action.name == 'Browser.Submit' { 'submit' } else { 'click' }
	return normalize_browser_operation(action.args['operation'] or { fallback })
}

pub fn browser_operation_is_textual(value string) bool {
	return normalize_browser_operation(value) in ['click_text', 'fill_text']
}

pub fn engine_hint_from_string(value string) EngineHint {
	clean := value.trim_space().to_lower().replace('-', '_')
	return match clean {
		'native', 'v', 'v_native' { .native }
		'webview', 'webview2', 'compatibility', 'chromium' { .webview }
		else { .auto }
	}
}

pub fn browser_operation_is_mutating(value string) bool {
	return normalize_browser_operation(value) in [
		'fill',
		'fill_text',
		'set_value',
		'submit',
		'check',
		'uncheck',
		'toggle',
		'select_value',
	]
}
