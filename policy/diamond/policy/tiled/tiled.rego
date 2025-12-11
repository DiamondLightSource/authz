package diamond.policy.tiled

import data.diamond.policy.session
import data.diamond.policy.token
import rego.v1

read_scopes := {
	"read:metadata",
	"read:data",
}

write_scopes := {
	"write:metadata",
	"write:data",
	"create",
	"register",
}

scopes_for(claims) := read_scopes | write_scopes if {
	"azp" in object.keys(claims)
	endswith(claims.azp, "-blueapi")
}

scopes_for(claims) := read_scopes if {
	"azp" in object.keys(claims)
	not endswith(claims.azp, "-blueapi")
}

scopes_for(claims) := read_scopes if {
	not "azp" in object.keys(claims)
}

default scopes := set()

scopes := scopes_for(token.claims)

user_sessions contains user_session if {
	some i in data.diamond.data.sessions
	session.access_session(token.claims.fedid, i.proposal_number, i.visit_number)
	user_session := sprintf(
		`{"proposal": %d, "visit": %d, "beamline": "%s"}`,
		[i.proposal_number, i.visit_number, i.beamline],
	)
}
