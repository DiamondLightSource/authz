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
	tiled.user_sessions == {"11", "12"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}
	tiled.user_sessions == {"11", "12", "13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "bob"}
	tiled.user_sessions == {"*"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
	tiled.user_sessions == {"13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "desmond"}
	tiled.user_sessions == {"13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "edna"}
}

test_user_session_allow if {
	tiled.user_session == "11" with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}

test_user_session_not_allowed if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
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
	tiled.user_session == "11" with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 1}
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_user_session_not_allow_service_account_wrong_beamline if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"beamline": "b07"}
}

test_user_session_not_allow_service_account_on_none_existent_beamline_beamline if {
	not tiled.user_session with data.diamond.data as diamond_data
		with input as {"beamline": "i03", "proposal": 1, "visit": 2}
		with data.diamond.policy.token.claims as {"beamline": "b007"}
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
	tiled.user_sessions == {"11"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "i03"}
	tiled.user_sessions == {"12", "13", "14"} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "b07"}
	tiled.user_sessions == set() with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "b007"}
}
