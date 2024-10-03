package diamond.policy.admin

import rego.v1

is_admin(subject) if {
	"super_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

is_beamline_admin(subject, beamline) if {
	some admin in data.diamond.data.subjects[subject].permissions
	beamline in data.diamond.data.admin[admin] # regal ignore:external-reference
}
