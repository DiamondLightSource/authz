package diamond.policy.proposal

import data.diamond.policy.admin
import rego.v1

on_proposal(subject, proposal_number) if {
	proposal_number in data.diamond.data.subjects[subject].proposals # regal ignore:external-reference
}

# Allow if subject has super_admin permission
access_proposal(subject, proposal_number) if admin.is_admin(subject)

# Allow if subject is on proposal
access_proposal(subject, proposal_number) if on_proposal(subject, proposal_number)
