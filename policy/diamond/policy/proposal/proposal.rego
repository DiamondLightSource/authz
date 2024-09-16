package diamond.policy.proposal

import rego.v1

# Allow if subject has super_admin permission
access_proposal(subject, proposal_number) if {
	"super_admin" in data.diamond.data.subjects[subject].permissions # regal ignore:external-reference
}

# Allow if subject is on proposal
access_proposal(subject, proposal_number) if {
	proposal_number in data.diamond.data.subjects[subject].proposals # regal ignore:external-reference
}
