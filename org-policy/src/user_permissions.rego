# METADATA
# scope: subpackages
# schemas:
#   - data.diamond.data.beamlines: schema["beamlines"]
#   - data.diamond.data.proposals: schema["proposals"]
#   - data.diamond.data.sessions: schema["sessions"]
#   - data.diamond.data.subjects: schema["subjects"]
package diamond.policy

import rego.v1

profile := http.send({
	"url": opa.runtime().env.PROFILE_ENDPOINT,
	"method": "GET",
	"headers": {"authorization": input.attributes.request.http.headers.authorization},
})

subject := profile.sub

can_read_from_session(proposal_number, session_number) if {
	subject_on_session(proposal_number, session_number)
}

can_write_to_session(proposal_number, session_number) if {
	subject_on_session(proposal_number, session_number)
}

subject_on_session(proposal_number, session_number) if {
	data.diamond.data.proposals[sprintf("%d", [proposal_number])].sessions[sprintf("%d", [session_number])] in data.diamond.data.subjects[subject].sessions
}
