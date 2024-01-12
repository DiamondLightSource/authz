package diamond.policy_test

import data.diamond.policy
import rego.v1

example_profile := {"sub": "laborum7"}

example_beamlines := {"Ut_b_b": {"sessions": [81672043]}}

example_proposals := {18759398: {"sessions": {1: 81672043}}}

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

test_default_not_allow if {
	not policy.user_on_session(18759398, 1) with policy.profile as {}
}

test_not_allow_without_user if {
	not policy.user_on_session(18759398, 1) with policy.profile as {}
		with data.diamond.data.sessions as example_sessions
		with data.diamond.data.proposals as example_proposals
		with data.diamond.data.beamlines as example_beamlines
		with data.diamond.data.subjects as example_subjects
}

test_not_allow_with_empty_context if {
	not policy.user_on_session(18759398, 1) with policy.profile as example_profile
		with data.diamond.data.sessions as {}
		with data.diamond.data.proposals as {}
		with data.diamond.data.beamlines as {}
		with data.diamond.data.subjects as {}
}

test_allow_if_user_on_session if {
	policy.user_on_session(18759398, 1) with policy.profile as example_profile
		with data.diamond.data.sessions as example_sessions
		with data.diamond.data.proposals as example_proposals
		with data.diamond.data.beamlines as {}
		with data.diamond.data.subjects as example_subjects
}

test_allow_if_user_on_sessions if {
	policy.user_on_session(18759398, 1) with policy.profile as example_profile
		with data.diamond.data.proposals as example_proposals
		with data.diamond.data.beamlines as {}
		with data.diamond.data.subjects as example_subjects
		with data.diamond.data.sessions as {
			"81672043": {
				"beamline": "Ut_b_b",
				"proposal_number": 18759398,
				"visit_number": 1,
			},
			"81672044": {
				"beamline": "Ut_b_b",
				"proposal_number": 18759398,
				"visit_number": 2,
			},
		}
}

test_allow_if_user_on_proposals if {
	policy.user_on_session(18759398, 1) with policy.profile as example_profile
		with data.diamond.data.proposals as {18759398: {"sessions": {1: 81672043}}, 18759399: {"sessions": {1: 81672044}}}
		with data.diamond.data.beamlines as {}
		with data.diamond.data.subjects as example_subjects
		with data.diamond.data.sessions as {
			"81672043": {
				"beamline": "Ut_b_b",
				"proposal_number": 18759398,
				"visit_number": 1,
			},
			"81672044": {
				"beamline": "Ut_b_b",
				"proposal_number": 18759399,
				"visit_number": 1,
			},
		}
}
