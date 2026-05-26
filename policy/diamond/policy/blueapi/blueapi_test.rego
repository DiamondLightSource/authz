package diamond.policy.blueapi_test

import data.diamond.policy.blueapi
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
	},
	"proposals": {"1": {"sessions": {
		"1": 11,
		"2": 12,
	}}},
	"beamlines": {"i03": {"sessions": [11]}, "b07": {"sessions": [12]}},
	"admin": {"b07_admin": ["b07"]},
}

test_service_account_if_beamline_matches if {
	blueapi.tiled_service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"]}
}

test_not_service_account_if_beamline_mismatch if {
	not blueapi.tiled_service_account_for_beamline with input as {"beamline": "b21"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"]}
}

test_not_service_account_if_missing_aud if {
	not blueapi.tiled_service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["blueapiCli"]}
}

test_not_service_account_if_fedid_present if {
	not blueapi.tiled_service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"], "fedid": "abc12345"}
}

test_user_session_not_allowed if {
	not blueapi.user_session with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 1, "beamline": "i03"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

test_user_session_allow if {
	blueapi.user_session with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 1, "beamline": "i03"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
}

# b07_admin user can access a b07 session via their role, not direct session membership
test_user_session_allow_for_beamline_admin_via_role if {
	blueapi.user_session with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 2, "beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
}

# Instrument session has to match instrument of blueapi instance test
test_user_session_not_allowed_if_instrument_session_doesnt_match_blueapi_instance if {
	not blueapi.user_session with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 1, "beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
}

# POST /tasks denied if user not on instrument session test
test_post_tasks_not_allowed_if_user_not_on_instrument_session if {
	not blueapi.post_task with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 1, "beamline": "i03"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

# POST /tasks allowed if user on instrument session test
test_post_tasks_allowed_if_user_on_instrument_session if {
	blueapi.post_task with data.diamond.data as diamond_data
		with input as {"proposal": 1, "visit": 1, "beamline": "i03"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
}

# DELETE /task denied if fed_id doesn't match task owner test
test_delete_task_not_allowed_if_fed_id_doesnt_match_task_owner if {
	not blueapi.delete_task with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

# DELETE /task allowed if fed_id matches task owner test
test_delete_task_allowed_if_fed_id_matches_task_owner if {
	blueapi.delete_task with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

# GET task/{task_id} denied if task not submitted by requesting user test
test_get_task_not_allowed_if_task_not_submitted_by_requesting_user if {
	not blueapi.fetch_task with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

# GET task/{task_id} allowed if task submitted by requesting user test
test_get_task_allowed_if_task_submitted_by_requesting_user if {
	blueapi.fetch_task with data.diamond.data as diamond_data
		with input as {"user": "oscar"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

# PUT /worker/state abort denied if not task creator test
test_put_worker_state_abort_not_allowed_if_not_task_creator if {
	not blueapi.put_worker_state_abort with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
}

# PUT /worker/state abort allowed if task creator test
test_put_worker_state_abort_allowed_if_task_creator if {
	blueapi.put_worker_state_abort with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
}

# DELETE /task allowed for admin regardless of task ownership
test_delete_task_allowed_for_admin if {
	blueapi.delete_task with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}

# GET /task/{task_id} allowed for admin regardless of task ownership
test_get_task_allowed_for_admin if {
	blueapi.fetch_task with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}

# PUT /worker/state abort allowed for admin regardless of task ownership
test_put_worker_state_abort_allowed_for_admin if {
	blueapi.put_worker_state_abort with data.diamond.data as diamond_data
		with input as {"user": "alice"}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
}
