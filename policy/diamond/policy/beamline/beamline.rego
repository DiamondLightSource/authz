package diamond.policy.beamline

import data.diamond.policy.admin
import data.diamond.policy.token
import rego.v1

subject := data.diamond.data.subjects[token.claims.fedid]

# METADATA
# title: User Beamlines
# description: |
#   Identifies all beamlines the subject is authorized to access
#   based on their assigned permissions.
# entrypoint: true
user_beamlines contains beamline if {
	token.claims.fedid
	not admin.is_admin(token.claims.fedid)
	some p in subject.permissions
	some beamline in object.get(data.diamond.data.admin, p, [])
}

user_beamlines contains beamline if {
	admin.is_admin(token.claims.fedid)
	some beamline in object.keys(data.diamond.data.beamlines)
}

user_beamlines contains token.claims.beamline if {
	token.claims.beamline in object.keys(data.diamond.data.beamlines)
}
