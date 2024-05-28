package diamond.policy.session

import data.diamond.policy.proposal
import rego.v1

beamline(proposal_number, visit_number) := beamline if {
	proposal := data.diamond.data.proposals[format_int(proposal_number, 10)] # regal ignore:external-reference
	session_id := proposal.sessions[format_int(visit_number, 10)]
	session := data.diamond.data.sessions[format_int(session_id, 10)] # regal ignore:external-reference
	beamline := session.beamline
}

# Allow if subject has super_admin permission
access_session(subject, proposal_number, visit_number) if {
	"super_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if subject on proposal which contains session
access_session(subject, proposal_number, visit_number) if {
	proposal.access_proposal(subject, proposal_number)
}

# Allow if subject directly on session
access_session(subject, proposal_number, visit_number) if {
	some session_id in data.diamond.data.subjects[subject].sessions # regal ignore:external-reference
	subject_session := data.diamond.data.sessions[format_int(session_id, 10)] # regal ignore:external-reference
	subject_session.proposal_number == proposal_number
	subject_session.visit_number == visit_number
}

# Allow if on session on b07 and subject has b07_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b07"
	"b07_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on b16 and subject has b16_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b16"
	"b16_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on b18 and subject has b18_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b18"
	"b18_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on b22 and subject has b22_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b22"
	"b22_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on b23 and subject has b23_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b23"
	"b23_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on b24 and subject has b24_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "b24"
	"b24_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i02-1 (VMXm) and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i02"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i02-2 (VMXi) and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i02-2"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i03 and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i03"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i04 and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i04"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i04-1 and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i04-1"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i05 and subject has i05_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i05"
	"i05_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i06 and subject has i06_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i06"
	"i06_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i07 and subject has i07_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i07"
	"i07_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i08 and subject has i08_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i08"
	"i08_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i09 and subject has i09_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i09"
	"i09_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i10 and subject has i10_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i10"
	"i10_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i11 and subject has i11_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i11"
	"i11_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i12 and subject has i12_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i12"
	"i12_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i13 and subject has i13_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i13"
	"i13_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i14 and subject has i14_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i14"
	"i14_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i16 and subject has i16_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i16"
	"i16_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i18 and subject has i18_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i18"
	"i18_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i20 and subject has i20_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i20"
	"i20_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i21 and subject has i21_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i21"
	"i21_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i23 and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i23"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on i24 and subject has mx_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "i24"
	"mx_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on k11 and subject has i11_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "k11"
	"k11_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on p45 and subject has p45_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "p45"
	"p45_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if on session on p99 and subject has p99_admin permission
access_session(subject, proposal_number, visit_number) if {
	beamline(proposal_number, visit_number) == "p99"
	"p99_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}
