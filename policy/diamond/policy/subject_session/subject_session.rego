package diamond.policy.subject_session

import data.diamond.policy.admin
import data.diamond.policy.token
import rego.v1

beamlines contains beamline if {
	some p in data.diamond.data.subjects[token.claims.fedid].permissions
	some beamline in object.get(data.diamond.data.admin, p, [])
}

tags contains to_number(tag) if {
	"super_admin" in data.diamond.data.subjects[token.claims.fedid].permissions
	some tag in object.keys(data.diamond.data.sessions)
}

tags contains to_number(tag) if {
	some tag in data.diamond.data.subjects[token.claims.fedid].sessions
}

tags contains to_number(tag) if {
	some beamline in beamlines
	some tag in data.diamond.data.beamlines[beamline].sessions
}

read_scopes := {
	"read:metadata",
	"read:data",
}

all_scopes := {
	"read:metadata",
	"read:data",
	"write:metadata",
	"write:data",
	"delete:revision",
	"delete:node",
	"create",
	"register",
}

scopes contains scope if {
	"blueapi" in token.claims.aud
	some scope in all_scopes
}

scopes contains scope if {
	some scope in read_scopes
}

default allow := false

# Allow to modify and create tiled node if the sessions are accessible to the user
allow if {
	every tag in input.access_blob.tags {
		to_number(tag) in tags
	}
}
