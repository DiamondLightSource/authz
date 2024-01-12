package application.policy_test

import rego.v1
import data.application.policy.allow

example_profile := {"sub": "laborum7"}

example_proposals := {"18759398": {"sessions": {"1": 81672043}}}

example_sessions := {"81672043": {
	"beamline": "Ut_b_b",
	"proposal_number": 18759398,
	"visit_number": 1,
}}

example_subjects := {"laborum7": {
	"permissions": ["dolor non"],
	"proposals": [18759398],
	"sessions": [81672043],
}}

test_allow_if_user_on_session if {
	allow with input as {"parsed_path": [18759398, 1]} with data.diamond.policy.profile as example_profile
		with data.diamond.data.sessions as example_sessions
		with data.diamond.data.proposals as example_proposals
		with data.diamond.data.beamlines as {}
		with data.diamond.data.subjects as example_subjects
}
