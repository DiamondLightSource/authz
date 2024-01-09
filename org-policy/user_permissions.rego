package diamond

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
	some allowed_session in data.diamond.users.sessions[subject]
	allowed_session[0] = proposalNumber
	allowed_session[1] = visitNumber
}

# METADATA
# entrypoint: true
user_on_proposal(proposalNumber) if {
	some allowed_proposal in data.diamond.users.proposals[subject]
	allowed_proposal = proposalNumber
}
