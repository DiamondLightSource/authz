package diamond.policy.proposal

import data.diamond.policy.token
import rego.v1

# METADATA
# description: Allow if subject is super_admin, or is on proposal
# entrypoint: true
default allow := false

# Allow if subject has super_admin permission
allow if {
	"super_admin" in data.diamond.data.subjects[token.subject].permissions
}

# Allow if subject is on proposal
allow if {
	input.parameters.proposal in data.diamond.data.subjects[token.subject].proposals
}
