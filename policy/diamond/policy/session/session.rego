package diamond.policy.session

import data.diamond.policy.admin
import data.diamond.policy.beamline as beamline_policy
import data.diamond.policy.proposal
import data.diamond.policy.token
import rego.v1

beamline_for(proposal_number, visit_number) := beamline if {
	proposal := data.diamond.data.proposals[format_int(proposal_number, 10)]
	session_id := proposal.sessions[format_int(visit_number, 10)]
	session := data.diamond.data.sessions[format_int(session_id, 10)]
	beamline := session.beamline
}

default on_session(_, _, _) := false

on_session(subject, proposal_number, visit_number) if {
	some session_id in data.diamond.data.subjects[subject].sessions
	subject_session := data.diamond.data.sessions[format_int(session_id, 10)]
	subject_session.proposal_number == proposal_number
	subject_session.visit_number == visit_number
}

default access_session(_, _, _) := false

# Allow if subject has super_admin permission
access_session(subject, _, _) if admin.is_admin(subject)

# Allow if subject is admin for beamline containing session
access_session(subject, proposal_number, visit_number) if {
	beamline_for(proposal_number, visit_number) in admin.beamline_admin_for_subject[subject]
}

# Allow if subject on proposal which contains session
access_session(subject, proposal_number, _) if proposal.on_proposal(subject, proposal_number)

# Allow if subject directly on session
access_session(subject, proposal_number, visit_number) if on_session(subject, proposal_number, visit_number)

# Rules depending on input data

access := access_session(token.claims.fedid, input.proposal, input.visit)

named_user := on_session(token.claims.fedid, input.proposal, input.visit)

beamline := beamline_for(input.proposal, input.visit)

# A user can only write to a visit if the given user, beamline and visit are all compatible
default write_to_beamline_visit := false

write_to_beamline_visit if {
	access
	input.beamline == beamline
}

subject := data.diamond.data.subjects[token.claims.fedid]

# METADATA
# title: User Sessions
# description: |
#   Aggregates all session IDs the subject is authorized to view.
#   Admins receive a wildcard "*" granting access to all sessions.
#   Regular users gain session access through three pathways:
#     1. Direct session membership
#     2. Access via beamline-level permissions
#     3. Access via proposal-level permissions
# entrypoint: false
# scope: document
user_sessions contains "*" if {
	subject
	admin.is_admin(token.claims.fedid)
}

# Direct session membership
user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some session in subject.sessions
}

# Access via beamline permissions
user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some _beamline in beamline_policy.user_beamlines
	some session in data.diamond.data.beamlines[_beamline].sessions
}

# Access via beamline permissions (service accounts)
user_sessions contains format_int(session, 10) if {
	not subject
	some _beamline in beamline_policy.user_beamlines
	some session in data.diamond.data.beamlines[_beamline].sessions
}

# Access via proposal permissions
user_sessions contains format_int(session, 10) if {
	subject
	not admin.is_admin(token.claims.fedid)
	some p in subject.proposals
	some i in data.diamond.data.proposals[format_int(p, 10)]
	some session in i
}
