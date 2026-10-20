package diamond.policy.tiled_test

import data.diamond.policy.tiled
import rego.v1

test_read_scopes if {
	tiled.scopes == {
		"read:metadata",
		"read:data",
	} with data.diamond.policy.token.claims as {}
}

test_tiled_writer_given_write_scopes if {
	tiled.scopes == {
		"read:metadata",
		"read:data",
		"write:metadata",
		"write:data",
		"create:node",
		"register",
	} with data.diamond.policy.token.claims as {"aud": ["tiled-writer"]}
}

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

test_user_session_tags if {
	tiled.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar"}

	# proposal member: proposal 1 runs on i03 and b07
	tiled.user_sessions == {
		"beamline:i03,proposal:1",
		"visible:beamline:i03",
		"beamline:b07,proposal:1",
		"visible:beamline:b07",
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}

	# b07 admin, and member of session 11 on i03: the beamline is one tag
	tiled.user_sessions == {
		"beamline:b07",
		"beamline:i03,proposal:1,session:1-1",
		"visible:beamline:i03,proposal:1",
		"visible:beamline:i03",
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "bob"}

	tiled.user_sessions == {"*"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}

	tiled.user_sessions == {
		"beamline:b07,proposal:2",
		"visible:beamline:b07",
		"beamline:b07,proposal:2,session:2-1",
		"visible:beamline:b07,proposal:2",
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "desmond"}

	tiled.user_sessions == {
		"beamline:b07,proposal:2",
		"visible:beamline:b07",
		"beamline:b07,proposal:2,session:2-1",
		"beamline:b07,proposal:2,session:2-2",
		"visible:beamline:b07,proposal:2",
	} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "edna"}
}

# tiled shows a node when any of its tags is in user_sessions. A session
# member must see the beamline and proposal above them and their own session,
# but not a sibling session or the beamline's other proposals.
shown(node_tags, allowed) if {
	some t in node_tags
	t in allowed
}

test_node_visibility_session_member if {
	# bob is a member of session 11 (i03, proposal 1, visit 1)
	allowed := tiled.user_sessions with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "bob"}
	shown(tiled.beamline_node_tags("i03"), allowed)
	shown(tiled.proposal_node_tags("i03", 1), allowed)
	shown(tiled.session_node_tags("i03", 1, 1), allowed)
	not shown(tiled.session_node_tags("i03", 1, 2), allowed)
	not shown(tiled.proposal_node_tags("i03", 2), allowed)
}

test_node_visibility_beamline_grant if {
	allowed := tiled.user_sessions with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "b07"}
	shown(tiled.beamline_node_tags("b07"), allowed)
	shown(tiled.proposal_node_tags("b07", 2), allowed)
	shown(tiled.session_node_tags("b07", 2, 2), allowed)
	not shown(tiled.beamline_node_tags("i03"), allowed)
	not shown(tiled.session_node_tags("i03", 1, 1), allowed)
}

test_user_session_allow if {
	tiled.user_session == [
		"beamline:i03,proposal:1,session:1-1",
		"beamline:i03,proposal:1",
		"beamline:i03",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1", "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}

test_user_session_not_allowed if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1", "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_not_modify_session if {
	not tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "13"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_modify_session if {
	tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "11"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

# Service account tests

test_user_session_allow_service_account_on_beamline if {
	tiled.user_session == [
		"beamline:i03,proposal:1,session:1-1",
		"beamline:i03,proposal:1",
		"beamline:i03",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1", "visit": 1}
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_user_session_not_allow_service_account_wrong_beamline if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1", "visit": 2}
		with data.diamond.policy.token.claims as {"beamline": "b07"}
}

test_user_session_not_allow_service_account_on_none_existent_beamline_beamline if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1", "visit": 2}
		with data.diamond.policy.token.claims as {"beamline": "b007"}
}

# A token carrying both fedid and beamline claims should still be judged as
# a named user (fedid's real permissions), not fall into the service-account
# branch just because the beamline claim happens to match the input.
test_user_session_not_allow_named_user_with_beamline_claim_and_no_access if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "b07", "proposal": "cm2", "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "alice", "beamline": "b07"}
}

# Same token (fedid and a beamline claim): no service-account access at any
# level, only what alice is granted herself.
test_named_user_with_beamline_claim_gets_only_own_access if {
	claims := {"fedid": "alice", "beamline": "b07"}
	allowed := tiled.user_sessions with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as claims
	allowed == tiled.user_sessions with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}
	not "beamline:b07" in allowed
	not shown(tiled.proposal_node_tags("b07", 2), allowed)
	not shown(tiled.session_node_tags("b07", 2, 1), allowed)
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as claims
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "b07", "proposal": "cm2"}
		with data.diamond.policy.token.claims as claims
	not tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "13"}
		with data.diamond.policy.token.claims as claims
}

test_modify_session_on_beamline if {
	tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "11"}
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_modify_session_on_wrong_beamline if {
	not tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "11"}
		with data.diamond.policy.token.claims as {"beamline": "b07"}
}

test_modify_session_on_none_existent_beamline if {
	not tiled.modify_session with data.diamond.data as diamond_data
		with input as {"session": "11"}
		with data.diamond.policy.token.claims as {"beamline": "b007"}
}

test_user_session_tags_service_account if {
	tiled.user_sessions == {"beamline:i03"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "i03"}
	tiled.user_sessions == {"beamline:b07"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "b07"}
	tiled.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "b007"}
}

# Level 1 & 2 node creation

test_user_session_beamline_level_allow if {
	tiled.user_session == [
		"beamline:b07",
		"visible:beamline:b07",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
}

test_user_session_beamline_level_denied if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_user_session_beamline_level_allow_service_account if {
	tiled.user_session == [
		"beamline:i03",
		"visible:beamline:i03",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "i03"}
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_user_session_proposal_level_allow if {
	tiled.user_session == [
		"beamline:i03,proposal:1",
		"beamline:i03",
		"visible:beamline:i03,proposal:1",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_user_session_proposal_level_denied_wrong_beamline if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i04", "proposal": "cm1"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_user_session_proposal_level_denied_no_access if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": "cm1"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_user_session_proposal_level_allow_service_account if {
	tiled.user_session == [
		"beamline:b07,proposal:2",
		"beamline:b07",
		"visible:beamline:b07,proposal:2",
	] with data.diamond.data as diamond_data
		with input as {"beamline": "b07", "proposal": "cm2"}
		with data.diamond.policy.token.claims as {"beamline": "b07"}
}
