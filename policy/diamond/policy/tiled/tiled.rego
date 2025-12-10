package diamond.policy.tiled

import data.diamond.policy.session.access_session
import data.diamond.policy.token

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
	some session in data.diamond.data.sessions
	access_session(token.claims.fedid, session.proposal_number, session.visit_number)
	user_session := sprintf("%s", [session])
}
