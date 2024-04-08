package diamond.policy.session

import data.diamond.policy.proposal
import data.diamond.policy.token
import rego.v1

# METADATA
# description: Allow if subject is super_admin, on proposal, has beamline admin permissions, or is on session
# entrypoint: true
default allow := false

# Allow if subject on proposal which contains session
allow if {
	proposal.allow
}

# Allow if subject has super_admin permission
allow if {
	"super_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if subject directly on session
allow if {
	some session_id in data.diamond.data.subjects[token.subject].sessions
	subject_session := data.diamond.data.sessions[format_int(session_id, 10)]
	subject_session.proposal_number == input.parameters.proposal
	subject_session.visit_number == input.parameters.visit
}

beamline := beamline if {
	proposal := data.diamond.data.proposals[format_int(input.parameters.proposal, 10)]
	session_id := proposal.sessions[format_int(input.parameters.visit, 10)]
	session := data.diamond.data.sessions[format_int(session_id, 10)]
	beamline := session.beamline
}

# Allow if on session on b07 and subject has b07_admin permission
allow if {
	beamline == "b07"
	"b07_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on b16 and subject has b16_admin permission
allow if {
	beamline == "b16"
	"b16_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on b18 and subject has b18_admin permission
allow if {
	beamline == "b18"
	"b18_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on b22 and subject has b22_admin permission
allow if {
	beamline == "b22"
	"b22_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on b23 and subject has b23_admin permission
allow if {
	beamline == "b23"
	"b23_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on b24 and subject has b24_admin permission
allow if {
	beamline == "b24"
	"b24_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i02-1 (VMXm) and subject has mx_admin permission
allow if {
	beamline == "i02"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i02-2 (VMXi) and subject has mx_admin permission
allow if {
	beamline == "i02-2"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i03 and subject has mx_admin permission
allow if {
	beamline == "i03"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i04 and subject has mx_admin permission
allow if {
	beamline == "i04"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i04-1 and subject has mx_admin permission
allow if {
	beamline == "i04-1"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i05 and subject has i05_admin permission
allow if {
	beamline == "i05"
	"i05_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i06 and subject has i06_admin permission
allow if {
	beamline == "i06"
	"i06_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i07 and subject has i07_admin permission
allow if {
	beamline == "i07"
	"i07_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i08 and subject has i08_admin permission
allow if {
	beamline == "i08"
	"i08_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i09 and subject has i09_admin permission
allow if {
	beamline == "i09"
	"i09_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i10 and subject has i10_admin permission
allow if {
	beamline == "i10"
	"i10_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i11 and subject has i11_admin permission
allow if {
	beamline == "i11"
	"i11_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i12 and subject has i12_admin permission
allow if {
	beamline == "i12"
	"i12_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i13 and subject has i13_admin permission
allow if {
	beamline == "i13"
	"i13_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i14 and subject has i14_admin permission
allow if {
	beamline == "i14"
	"i14_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i16 and subject has i16_admin permission
allow if {
	beamline == "i16"
	"i16_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i18 and subject has i18_admin permission
allow if {
	beamline == "i18"
	"i18_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i20 and subject has i20_admin permission
allow if {
	beamline == "i20"
	"i20_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i21 and subject has i21_admin permission
allow if {
	beamline == "i21"
	"i21_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i23 and subject has mx_admin permission
allow if {
	beamline == "i23"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on i24 and subject has mx_admin permission
allow if {
	beamline == "i24"
	"mx_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on k11 and subject has i11_admin permission
allow if {
	beamline == "k11"
	"k11_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on p45 and subject has p45_admin permission
allow if {
	beamline == "p45"
	"p45_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if on session on p99 and subject has p99_admin permission
allow if {
	beamline == "p99"
	"p99_admin" in data.diamond.data.subjects[token.subject].permissions
}
