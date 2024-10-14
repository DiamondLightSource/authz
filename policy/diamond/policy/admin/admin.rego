package diamond.policy.admin

import rego.v1

is_admin[subject] := "super_admin" in data.diamond.data.subjects[subject].permissions

beamline_admin_for_subject[subject] contains beamline if {
	some subject
	some role in data.diamond.data.subjects[subject].permissions
	some beamline in data.diamond.data.admin[role]
}

admin := is_admin[input.user] # regal ignore:rule-name-repeats-package

beamline_admin := input.beamline in object.get(beamline_admin_for_subject, input.user, [])
