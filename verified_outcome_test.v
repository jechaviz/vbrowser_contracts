module vbrowser_contracts

fn success_handoff_for_test() BrowserHandoff {
	return BrowserHandoff{
		source: 'browser'
		destination: 'client'
		intent: classify_input('verified', 'https://example.com')
		evidence: [
			ActionEvidence{
				action_id: 'open'
				phase: .succeeded
			},
			ActionEvidence{
				action_id: 'browser-state'
				phase: .succeeded
			},
		]
	}
}

fn test_verified_success_requires_terminal_state() {
	good := success_handoff_for_test()
	assert good.verified_success()
	no_state := BrowserHandoff{
		...good
		evidence: [ActionEvidence{action_id: 'open', phase: .succeeded}]
	}
	assert !no_state.verified_success()
}

fn test_verified_success_rejects_mixed_action_outcomes() {
	good := success_handoff_for_test()
	for phase in [ActionPhase.failed, .cancelled, .awaiting_confirmation, .running] {
		mut evidence := good.evidence.clone()
		evidence << ActionEvidence{
			action_id: 'submit'
			phase: phase
		}
		mixed := BrowserHandoff{
			...good
			evidence: evidence
		}
		assert !mixed.verified_success()
	}
}

fn test_verified_success_rejects_pending_and_incompatible_handoffs() {
	good := success_handoff_for_test()
	pending := BrowserHandoff{
		...good
		pending: [
			action_for_intent('open', good.intent, 'Browser.Open',
				{'url': 'https://example.com'}, BrowserTarget{url: 'https://example.com'}, 0),
		]
	}
	assert !pending.verified_success()
	incompatible := BrowserHandoff{
		...good
		version: '999.0.0'
	}
	assert !incompatible.verified_success()
}

fn test_verified_success_rejects_later_unverified_state() {
	good := success_handoff_for_test()
	mut evidence := good.evidence.clone()
	evidence << ActionEvidence{
		action_id: 'browser-state'
		phase: .proposed
	}
	late := BrowserHandoff{
		...good
		evidence: evidence
	}
	assert !late.verified_success()
}
