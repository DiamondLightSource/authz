package diamond.policy.session_test

import data.diamond.policy.session
import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [1],
			"sessions": [],
		},
		"bob": {
			"permissions": ["b07_admin"],
			"proposals": [],
			"sessions": [11],
		},
		"carol": {
			"permissions": ["super_admin"],
			"proposals": [],
			"sessions": [],
		},
		"desmond": {
			"permissions": [],
			"proposals": [2],
			"sessions": [13],
		},
		"edna": {
			"permissions": [],
			"proposals": [2],
			"sessions": [13, 14],
		},
		"oscar": {
			"permissions": [],
			"proposals": [],
			"sessions": [],
		},
	},
	"sessions": {
		"11": {
			"beamline": "i03",
			"proposal_number": 1,
			"visit_number": 1,
		},
		"12": {
			"beamline": "b07",
			"proposal_number": 1,
			"visit_number": 2,
		},
		"13": {
			"beamline": "b07",
			"proposal_number": 2,
			"visit_number": 1,
		},
		"14": {
			"beamline": "b07",
			"proposal_number": 2,
			"visit_number": 2,
		},
	},
	"proposals": {
		"1": {"sessions": {
			"1": 11,
			"2": 12,
		}},
		"2": {"sessions": {
			"1": 13,
			"2": 14,
		}},
	},
	"beamlines": {"i03": {"sessions": [11]}, "b07": {"sessions": [12, 13, 14]}},
	"admin": {"b07_admin": ["b07"]},
}

test_session_member_allowed if {
	session.access_session("bob", 1, 1) with data.diamond.data as diamond_data
}

test_proposal_member_allowed if {
	session.access_session("alice", 1, 1) with data.diamond.data as diamond_data
}

test_beamline_admin_allowed if {
	session.access_session("bob", 1, 2) with data.diamond.data as diamond_data
}

test_super_admin_allowed if {
	session.access_session("carol", 1, 2) with data.diamond.data as diamond_data
}

test_non_member_denied if {
	not session.access_session("oscar", 1, 1) with data.diamond.data as diamond_data
}

test_admin_not_on_session if {
	not session.on_session("carol", 1, 1) with data.diamond.data as diamond_data
}

test_access_rule_for_named_user if {
	session.access with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_access_rule_for_beamline_admin if {
	session.access with input as {"proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_access_rule_for_super_admin if {
	session.access with input as {"proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
		with data.diamond.data as diamond_data
}

test_access_rule_for_non_user if {
	not session.access with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
		with data.diamond.data as diamond_data
}

test_access_rule_for_no_user if {
	not session.access with input as {"proposal": 1, "visit": 2}
		with data.diamond.data as diamond_data
}

test_access_rule_for_no_proposal if {
	not session.access with input as {"visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_access_rule_for_no_visit if {
	not session.access with input as {"proposal": 2}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_named_user if {
	session.named_user with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_unnamed_user if {
	not session.named_user with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_super_admin if {
	not session.named_user with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_beamline_admin if {
	not session.named_user with input as {"proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_named_user_rule_for_named_proposal if {
	# Users on the proposal can access the session but aren't named on it
	not session.named_user with input as {"proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_write_to_beamline_rule_for_match if {
	session.write_to_beamline_visit with input as {"beamline": "b07", "proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_write_to_beamline_rule_for_non_match if {
	not session.write_to_beamline_visit with input as {"beamline": "b07", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_write_to_beamline_rule_for_no_beamline if {
	not session.write_to_beamline_visit with input as {"proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_write_to_beamline_rule_for_no_visit if {
	not session.write_to_beamline_visit with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_session_beamline if {
	bl1 := session.beamline with input as {"proposal": 1, "visit": 1}
		with data.diamond.data as diamond_data
	bl1 == "i03"

	bl2 := session.beamline with input as {"proposal": 1, "visit": 2}
		with data.diamond.data as diamond_data
	bl2 == "b07"
}

test_user_sessions if {
	session.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
	session.user_sessions == {"11", "12"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}
	session.user_sessions == {"11", "12", "13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "bob"}
	session.user_sessions == {"*"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
	session.user_sessions == {"13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "desmond"}
	session.user_sessions == {"13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "edna"}
	session.user_sessions == {"11"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "i03"}
	session.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "area-51-beamline"}
}
