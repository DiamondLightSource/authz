package diamond.policy.proposal

import data.diamond.policy.admin
import data.diamond.policy.token
import rego.v1

default on_proposal(_, _) := false

on_proposal(subject, proposal_number) if {
	proposal_number in data.diamond.data.subjects[subject].proposals # regal ignore:external-reference
}

default access_proposal(_, _) := false

# Allow if subject has super_admin permission
access_proposal(subject, proposal_number) if admin.is_admin[subject] # regal ignore:external-reference

# Allow if subject is on proposal
access_proposal(subject, proposal_number) if on_proposal(subject, proposal_number)

access := access_proposal(token.claims.fedid, input.proposal)

named_user := on_proposal(token.claims.fedid, input.proposal)
