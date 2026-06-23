package diamond.policy.ulims

import data.diamond.policy.admin
import data.diamond.policy.beamline
import data.diamond.policy.session
import data.diamond.policy.token
import rego.v1

# METADATA
# title: Session Restrictions
# description: |
#   Return the instrument sessions the current user is allowed to see, or null if the user is an admin
#   Requires:
#     - `input.token`, a JWT
# entrypoint: true
default session_restrictions := []

session_restrictions := null if {
	admin.is_admin(token.claims.fedid)
}

session_restrictions := [data.diamond.data.sessions[session_id] | some session_id in session.user_sessions] if {
	not admin.is_admin(token.claims.fedid)
}

session_restrictions := [data.diamond.data.sessions[session_id] | some session_id in session.user_sessions] if {
	not token.claims.fedid
}

# METADATA
# title: Filter sessions
# description: |
#   Filter a provided list of instrument sessions, returning just those that the user has access to
#   Requires:
#     - `input.token`, a JWT
#     - `input.instrument_sessions`, an array representing a list of instrument sessions, [(proposal, visit), ...]
# entrypoint: true
filter_sessions contains _session if {
	"*" in session.user_sessions
	some _session in input.instrument_sessions
	proposal_number := format_int(_session[0], 10)
	proposal_number in object.keys(data.diamond.data.proposals)
	session_number := format_int(_session[1], 10)
	session_number in object.keys(data.diamond.data.proposals[proposal_number].sessions)
}

filter_sessions contains _session if {
	not "*" in session.user_sessions
	some _session in input.instrument_sessions
	proposal_number := format_int(_session[0], 10)
	session_number := format_int(_session[1], 10)
	format_int(data.diamond.data.proposals[proposal_number].sessions[session_number], 10) in session.user_sessions
}

# METADATA
# title: Filter instruments
# description: |
#   Filter a provided list of instruments, returning just those that the user has access to
#   Requires:
#     - `input.token`, a JWT
#     - `input.instruments`, an array of strings representing a list of instruments
# entrypoint: true
filter_instruments contains _beamline if {
	some _beamline in input.instruments
	_beamline in object.keys(data.diamond.data.beamlines)
	_beamline in beamline.user_beamlines
}
