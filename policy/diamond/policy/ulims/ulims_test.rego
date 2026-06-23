package diamond.policy.ulims_test

import data.diamond.policy.ulims
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
			"sessions": [],
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

test_session_restrictions_for_admin if {
	ulims.session_restrictions == null with data.diamond.data as diamond_data
		with data.diamond.policy.token as {"claims": {"fedid": "carol"}}
}

test_session_restrictions_for_non_admin_1 if {
	ulims.session_restrictions == [
		{
			"beamline": "i03",
			"proposal_number": 1,
			"visit_number": 1,
		},
		{
			"beamline": "b07",
			"proposal_number": 1,
			"visit_number": 2,
		},
	]
		with data.diamond.data as diamond_data
		with data.diamond.policy.token as {"claims": {"fedid": "alice"}}
}

test_session_restrictions_for_non_admin_2 if {
	ulims.session_restrictions == [] with data.diamond.data as diamond_data
		with data.diamond.policy.token as {"claims": {"fedid": "oscar"}}
}

test_session_restrictions_service_account if {
	ulims.session_restrictions == [{
		"beamline": "i03",
		"proposal_number": 1,
		"visit_number": 1,
	}]
		with data.diamond.data as diamond_data
		with data.diamond.policy.token.claims as {"beamline": "i03"}
}

test_filter_sessions_for_admin if {
	ulims.filter_sessions == {[1, 1], [1, 2], [2, 1], [2, 2]} with data.diamond.data as diamond_data
		with input.instrument_sessions as [[1, 1], [1, 2], [2, 1], [2, 2]]
		with data.diamond.policy.token as {"claims": {"fedid": "carol"}}
}

test_filter_sessions_beamline_admin if {
	ulims.filter_sessions == {[1, 2], [2, 1], [2, 2]} with data.diamond.data as diamond_data
		with input.instrument_sessions as [[1, 1], [1, 2], [2, 1], [2, 2]]
		with data.diamond.policy.token as {"claims": {"fedid": "bob"}}
}

test_filter_sessions_for_non_admin_1 if {
	ulims.filter_sessions == {[1, 1], [1, 2]} with data.diamond.data as diamond_data
		with input.instrument_sessions as [[1, 1], [1, 2], [2, 1], [2, 2]]
		with data.diamond.policy.token as {"claims": {"fedid": "alice"}}
}

test_filter_sessions_for_non_admin_2 if {
	ulims.filter_sessions == set() with data.diamond.data as diamond_data
		with input.instrument_sessions as [[1, 1], [1, 2], [2, 1], [2, 2]]
		with data.diamond.policy.token as {"claims": {"fedid": "oscar"}}
}

test_filter_sessions_service_account if {
	ulims.filter_sessions == {[1, 1]} with data.diamond.data as diamond_data
		with input.instrument_sessions as [[1, 1], [1, 2], [2, 1], [2, 2]]
		with data.diamond.policy.token as {"claims": {"beamline": "i03"}}
}

test_filter_sessions_non_existent_session if {
	ulims.filter_sessions == set() with data.diamond.data as diamond_data
		with input.instrument_sessions as [[999, 999]]
		with data.diamond.policy.token as {"claims": {"fedid": "carol"}}
}

test_filter_instruments_user if {
	ulims.filter_instruments == set() with data.diamond.data as diamond_data
		with input.instruments as ["i03", "b07"]
		with data.diamond.policy.token as {"claims": {"fedid": "alice"}}
}

test_filter_instruments_beamline_admin if {
	ulims.filter_instruments == {"b07"} with data.diamond.data as diamond_data
		with input.instruments as ["i03", "b07"]
		with data.diamond.policy.token as {"claims": {"fedid": "bob"}}
}

test_filter_instruments_super_admin if {
	ulims.filter_instruments == {"i03", "b07"} with data.diamond.data as diamond_data
		with input.instruments as ["i03", "b07"]
		with data.diamond.policy.token as {"claims": {"fedid": "carol"}}
}

test_filter_instruments_service_account if {
	ulims.filter_instruments == {"i03"} with data.diamond.data as diamond_data
		with input.instruments as ["i03", "b07"]
		with data.diamond.policy.token as {"claims": {"beamline": "i03"}}
}

test_filter_instruments_non_existent_instrument if {
	ulims.filter_instruments == set() with data.diamond.data as diamond_data
		with input.instruments as ["area-51-beamline"]
		with data.diamond.policy.token as {"claims": {"fedid": "carol"}}
}
