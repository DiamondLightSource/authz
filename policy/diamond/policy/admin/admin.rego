package diamond.policy.admin

import data.diamond.policy.token
import rego.v1

is_admin[subject] := "super_admin" in data.diamond.data.subjects[subject].permissions

beamline_admin_for_subject[subject_name] contains beamline if {
	some subject_name, subject in data.diamond.data.subjects
	some subject_role in subject.permissions
	some role, role_beamlines in data.diamond.data.admin
	subject_role == role
	some beamline in role_beamlines
}

admin := is_admin[token.claims.fedid] # regal ignore:rule-name-repeats-package

beamline_admin := input.beamline in object.get(beamline_admin_for_subject, token.claims.fedid, [])

# Users can change configuration for a beamline if they are either an admin for that beamline or a super admin
default configure_beamline := false

configure_beamline if admin

configure_beamline if beamline_admin
