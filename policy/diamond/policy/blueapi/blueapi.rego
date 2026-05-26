package diamond.policy.blueapi

import data.diamond.policy.admin
import data.diamond.policy.session
import data.diamond.policy.token

import rego.v1

default tiled_service_account_for_beamline := false

tiled_service_account_for_beamline if {
	input.beamline == token.claims.beamline
	"tiled-writer" in token.claims.aud
	not token.claims.fedid
}

_session := data.diamond.data.proposals[format_int(input.proposal, 10)].sessions[format_int(input.visit, 10)]

# Returns the session ID if the subject has write permissions for the
# specific beamline, visit and proposal requested in the input.
user_session := format_int(_session, 10) if {
	session.write_to_beamline_visit
	_session
}

# Check if user should be able to submit tasks only if they're on
# the same instrument as the instrument session in question.

default post_task := false

post_task if {
	session.write_to_beamline_visit
}

default delete_task := false

delete_task if {
	input.user == token.claims.fedid
}

delete_task if {
	admin.is_admin(token.claims.fedid)
}

default fetch_task := false

fetch_task if {
	input.user == token.claims.fedid
}

fetch_task if {
	admin.is_admin(token.claims.fedid)
}

default put_worker_state_abort := false

put_worker_state_abort if {
	input.user == token.claims.fedid
}

put_worker_state_abort if {
	admin.is_admin(token.claims.fedid)
}
