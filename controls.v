module vbrowser_contracts

pub struct ControlMatch {
pub:
	control PageControl
	score   int
}

pub fn rank_page_controls(controls []PageControl, query string, roles []string) []ControlMatch {
	needle := normalize_control_text(query)
	mut allowed := []string{cap: roles.len}
	for role in roles {
		clean := role.trim_space().to_lower()
		if clean != '' {
			allowed << clean
		}
	}
	mut out := []ControlMatch{}
	for control in controls {
		if control.disabled {
			continue
		}
		if allowed.len > 0 && control.role.to_lower() !in allowed {
			continue
		}
		label := control_search_text(control)
		mut score := control_role_priority(control)
		if needle != '' {
			haystack := normalize_control_text(label)
			if haystack == needle {
				score += 100
			} else if haystack.starts_with(needle) || haystack.ends_with(needle) {
				score += 70
			} else if haystack.contains(needle) {
				score += 50
			} else {
				mut overlap := 0
				for word in needle.split(' ') {
					if word.len >= 2 && haystack.contains(word) {
						overlap++
					}
				}
				if overlap == 0 {
					continue
				}
				score += overlap * 10
			}
		}
		out << ControlMatch{
			control: control
			score: score
		}
	}
	for i := 1; i < out.len; i++ {
		mut j := i
		for j > 0 && out[j].score > out[j - 1].score {
			tmp := out[j - 1]
			out[j - 1] = out[j]
			out[j] = tmp
			j--
		}
	}
	return out
}

pub fn page_control_by_id(controls []PageControl, id string) ?PageControl {
	for control in controls {
		if control.id == id {
			return control
		}
	}
	return none
}

pub fn page_control_is_editable(control PageControl) bool {
	return !control.disabled && control.role.to_lower() in ['textbox', 'searchbox']
}

pub fn page_control_is_clickable(control PageControl) bool {
	return !control.disabled && control.role.to_lower() in [
		'button',
		'link',
		'checkbox',
		'radio',
		'combobox',
		'tab',
		'menuitem',
	]
}

pub fn page_control_is_navigable(control PageControl) bool {
	return !control.disabled && control.href.trim_space() != ''
}

fn control_search_text(control PageControl) string {
	return [
		control.label,
		control.name,
		control.value,
		control.role,
		control.href,
		control.id,
	].filter(it.trim_space() != '').join(' ')
}

fn control_role_priority(control PageControl) int {
	return match control.role.to_lower() {
		'searchbox' { 35 }
		'textbox' { 30 }
		'button' { 25 }
		'link' { 20 }
		'checkbox', 'radio', 'combobox' { 15 }
		else { 5 }
	}
}

fn normalize_control_text(value string) string {
	return value.to_lower().split_any(' \t\r\n,.;:!?()[]{}"\'').filter(it != '').join(' ')
}
