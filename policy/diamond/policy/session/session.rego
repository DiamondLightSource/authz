package diamond.policy.session

import data.diamond.policy.admin
import data.diamond.policy.proposal
import rego.v1

beamline(proposal_number, visit_number) := beamline if {
	proposal := data.diamond.data.proposals[format_int(proposal_number, 10)] # regal ignore:external-reference
	session_id := proposal.sessions[format_int(visit_number, 10)]
	session := data.diamond.data.sessions[format_int(session_id, 10)] # regal ignore:external-reference
	beamline := session.beamline
}

on_session(subject, proposal_number, visit_number) if {
	some session_id in data.diamond.data.subjects[subject].sessions # regal ignore:external-reference
	subject_session := data.diamond.data.sessions[format_int(session_id, 10)] # regal ignore:external-reference
	subject_session.proposal_number == proposal_number
	subject_session.visit_number == visit_number
}

# Allow if subject has super_admin permission
access_session(subject, proposal_number, visit_number) if admin.is_admin(subject)

# Allow if subject is admin for beamline containing session
access_session(subject, proposal_number, visit_number) if {
	admin.is_beamline_admin(subject, beamline(proposal_number, visit_number))
}

# Allow if subject on proposal which contains session
access_session(subject, proposal_number, visit_number) if proposal.on_proposal(subject, proposal_number)

# Allow if subject directly on session
access_session(subject, proposal_number, visit_number) if on_session(subject, proposal_number, visit_number)
