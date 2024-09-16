package diamond.policy.proposal_test

import data.diamond.policy.proposal
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
	proposal.access_proposal("alice", 1) with data.diamond.data as diamond_data
}

test_super_admin_allowed if {
	proposal.access_proposal("carol", 1) with data.diamond.data as diamond_data
}

test_non_member_denied if {
	not proposal.access_proposal("oscar", 1) with data.diamond.data as diamond_data
}
