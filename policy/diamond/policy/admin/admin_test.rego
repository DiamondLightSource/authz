package diamond.policy.admin_test

import data.diamond.policy.admin
import rego.v1

diamond_data := {
	"subjects": {
		"alice": {
			"permissions": [],
			"proposals": [],
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
		"oscar": {
			"permissions": ["group_admin"],
			"proposals": [],
			"sessions": [],
		},
	},
	"sessions": {},
	"proposals": {},
	"beamlines": {},
	"admin": {"b07_admin": ["b07"], "group_admin": ["b07", "i07"]},
}

test_is_admin_for_admin if {
	admin.is_admin.carol with data.diamond.data as diamond_data
}

test_beamline_admin_for_subject_for_beamline_admin if {
	admin.beamline_admin_for_subject.bob == {"b07"} with data.diamond.data as diamond_data
}

test_beamlines_admin_for_subject_for_group_admin if {
	admin.beamline_admin_for_subject.oscar == {"b07", "i07"} with data.diamond.data as diamond_data
}

test_is_admin_for_non_admin if {
	not admin.is_admin.alice with data.diamond.data as diamond_data
}

test_is_admin_for_beamline_admin_not_admin if {
	not admin.is_admin.bob with data.diamond.data as diamond_data
}

test_beamline_admin_for_subject_for_non_beamline_admin if {
	not "alice" in admin.beamline_admin_for_subject with data.diamond.data as diamond_data
}

test_beamline_admin_for_subject_for_admin if {
	not "carol" in admin.beamline_admin_for_subject with data.diamond.data as diamond_data
}

test_admin_rule_for_admin if {
	admin.admin with data.diamond.policy.token.claims as {"fedid": "carol"}
		with data.diamond.data as diamond_data
}

test_admin_rule_for_non_admin if {
	not admin.admin with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

# If no user is passed as input, the rule should be undefined
test_admin_rule_for_no_user := false if {
	local_admin := admin.admin with data.diamond.policy.token.claims as {}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_beamline_admin_rule_for_beamline_admin if {
	admin.beamline_admin with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

# super_admin can access anything but they still aren't automatically beamline admins
test_beamline_admin_rule_for_super_admin if {
	not admin.beamline_admin with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "carol"}
		with data.diamond.data as diamond_data
}

test_beamline_admin_rule_for_non_beamline_admin if {
	not admin.beamline_admin with input as {"beamline": "b07"}
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as diamond_data
}

test_beamline_admin_rule_for_wrong_beamline_admin if {
	# bob is only beamline admin for b07
	not admin.beamline_admin with input as {"beamline": "i07"}
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

test_beamline_admin_rule_for_no_user := false if {
	local_admin := admin.beamline_admin with input as {"beamline": "i07"}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_beamline_admin_rule_for_no_beamline := false if {
	local_admin := admin.beamline_admin with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else

test_beamline_admin_rule_for_no_input := false if {
	local_admin := admin.beamline_admin with input as {}
		with data.diamond.data as diamond_data
}

else := true # regal ignore:default-over-else
