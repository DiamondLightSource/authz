package diamond

import future.keywords

# METADATA
# entrypoint: true
default allow := false

allow if {
	user_on_proposal
}

allow if {
	user_on_session
}

user_on_session if {
	some session in data.sessions[input.user]
	session[0] == input.session
}

user_on_proposal if {
	some proposal in data.proposals[input.user]
	proposal == input.proposal
}
