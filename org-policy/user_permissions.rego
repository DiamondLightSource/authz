package diamond.policy

import rego.v1

profile := http.send({
	"url": opa.runtime().env.PROFILE_ENDPOINT,
	"method": "GET",
	"headers": {"authorization": input.attributes.request.http.headers.authorization},
})

subject := profile.sub

# METADATA
# entrypoint: true
user_on_session(proposalNumber, visitNumber) if {
	[proposalNumber, visitNumber] in data.diamond.data.users.sessions[subject]
}

# METADATA
# entrypoint: true
user_on_proposal(proposalNumber) if {
	proposalNumber in data.diamond.data.users.proposals[subject]
}
