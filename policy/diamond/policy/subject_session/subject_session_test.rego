package diamond.policy.subject_session_test

import data.diamond.policy.subject_session

import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [1],
			"sessions": [1, 2],
		},
		"carol": {
			"permissions": ["super_admin"],
			"proposals": [],
			"sessions": [],
		},
		"oscar": {
			"permissions": ["b07_admin"],
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
	},
	"proposals": {"1": {"sessions": {
		"1": 11,
		"2": 12,
	}}},
	"beamlines": {"i03": {"sessions": [11]}, "b07": {"sessions": [12]}},
	"admin": {"b07_admin": ["b07"]},
}

test_tags_for_super_admin if {
	subject_session.tags == {11, 12} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}

test_tags_form_subject_sessions if {
	subject_session.tags == {1, 2} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

test_tags_from_subject_beamline_permissions if {
	subject_session.tags == {12} with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_scopes_for_subject if {
	subject_session.scopes == subject_session.read_scopes with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_scopes_for_subject_all_scopes_if_blueapi if {
	subject_session.scopes == subject_session.all_scopes with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "oscar", "aud": ["blueapi"]}
}

test_allow if {
	subject_session.allow with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
		with input as {"access_blob": {"tags": ["11", "12"]}}
}

test_allow_denied if {
	not subject_session.allow with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"fedid": "carol"}
		with input as {"access_blob": {"tags": ["1"]}}
}
