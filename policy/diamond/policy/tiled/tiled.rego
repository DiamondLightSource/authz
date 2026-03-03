package diamond.policy.tiled

import data.diamond.policy.admin
import data.diamond.policy.session
import data.diamond.policy.token
import rego.v1

# Assign read & write scopes to clients with tiled-writer audience
# defaults to read-only scopes
default scopes := {
	"read:metadata",
	"read:data",
}

scopes := {
	"read:metadata",
	"read:data",
	"write:metadata",
	"write:data",
	"create:node",
	"register",
} if {
	"tiled-writer" in token.claims.aud
}

_session := data.diamond.data.proposals[format_int(input.proposal, 10)].sessions[format_int(input.visit, 10)]

# Returns the session ID if the subject has write permissions for the
# specific beamline, visit and proposal requested in the input.
user_session := format_int(_session, 10) if {
	session.write_to_beamline_visit
	_session
}

# service account check
user_session := format_int(_session, 10) if {
	input.beamline == token.claims.beamline
	input.beamline == session.beamline_for(input.proposal, input.visit)
	_session in data.diamond.data.beamlines[input.beamline].sessions
}

# Validates if the subject has permission to modify
# the specific session in the input.
default modify_session := false

modify_session if session.access_session(
	token.claims.fedid,
	data.diamond.data.sessions[input.session].proposal_number,
	data.diamond.data.sessions[input.session].visit_number,
)

# service account check
modify_session if {
	not token.claims.fedid
	session.beamline_for(
		data.diamond.data.sessions[input.session].proposal_number,
		data.diamond.data.sessions[input.session].visit_number,
	) == token.claims.beamline
}

subject := data.diamond.data.subjects[token.claims.fedid]

# Identifies all beamlines the subject is authorized to access
# based on their assigned permissions.
beamlines contains beamline if {
	token.claims.fedid
	not admin.is_admin(token.claims.fedid)
	some p in subject.permissions
	some beamline in object.get(data.diamond.data.admin, p, [])
}

# Aggregates all session IDs the subject is authorized to view.
# Admins receive a wildcard "*" granting access to all sessions.

# Regular users gain session access through three pathways:
# 1. Direct session membership
# 2. Access via beamline-level permissions
# 3. Access via proposal-level permissions
user_sessions contains "*" if {
	subject
	admin.is_admin(token.claims.fedid)
}

user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some session in subject.sessions
}

user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some beamline in beamlines
	some session in data.diamond.data.beamlines[beamline].sessions
}

user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some p in subject.proposals
	some i in data.diamond.data.proposals[format_int(p, 10)]
	some session in i
}

# service account check
user_sessions contains format_int(session, 10) if {
	not subject
	some session in data.diamond.data.beamlines[token.claims.beamline].sessions
}
