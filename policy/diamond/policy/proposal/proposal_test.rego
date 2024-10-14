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

test_member_on_proposal if {
	proposal.on_proposal("alice", 1) with data.diamond.data as diamond_data
}

test_admin_not_on_proposal if {
	not proposal.on_proposal("carol", 1) with data.diamond.data as diamond_data
}

test_named_user_rule_for_named_user if {
	proposal.named_user with input as {"user": "alice", "proposal": 1}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_unnamed_user if {
	not proposal.named_user with input as {"user": "carol", "proposal": 1}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_no_user := false if {
	named := proposal.named_user with input as {"proposal": 1}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_named_user_rule_for_no_proposal := false if {
	named := proposal.named_user with input as {"user": "carol"}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_access_rule_for_super_admin if {
	proposal.access with input as {"user": "carol", "proposal": 1}
		with data.diamond.data as diamond_data
}

test_access_rule_for_named_user if {
	proposal.access with input as {"user": "alice", "proposal": 1}
		with data.diamond.data as diamond_data
}

test_access_rule_for_unnamed_user if {
	not proposal.access with input as {"user": "oscar", "proposal": 1}
		with data.diamond.data as diamond_data
}

test_access_rule_for_no_user := false if {
	access := proposal.access with input as {"proposal": 1}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_access_rule_for_no_proposal := false if {
	access := proposal.access with input as {"user": "alice"}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else
