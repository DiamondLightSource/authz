package diamond.policy.proposal_test

import data.diamond.policy.proposal
import data.diamond.policy.token
import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [1],
			"sessions": [],
		},
		"carol": {
			"permissions": ["super_admin"],
			"proposals": [],
			"sessions": [],
		},
		"oscar": {
			"permissions": [],
			"proposals": [],
			"sessions": [],
		},
	},
	"proposals": {"1": {"sessions": {}}},
}

test_member_allowed if {
	proposal.allow with token.subject as "alice"
		with input as {"parameters": {"proposal": 1}}
		with data.diamond.data as diamond_data
}

test_super_admin_allowed if {
	proposal.allow with token.subject as "carol"
		with input as {"parameters": {"proposal": 1, "visit": 1}}
		with data.diamond.data as diamond_data
}

test_non_member_denied if {
	not proposal.allow with token.subject as "oscar"
		with input as {"parameters": {"proposal": 1}}
		with data.diamond.data as diamond_data
}
