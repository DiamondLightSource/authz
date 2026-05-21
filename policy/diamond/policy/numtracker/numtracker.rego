package diamond.policy.numtracker

import data.diamond.policy.session
import data.diamond.policy.token

import rego.v1

default write_to_beamline_visit := false

# User account check
write_to_beamline_visit if {
	session.access
	input.beamline == session.beamline
}

# Service account check
write_to_beamline_visit if {
	input.beamline == token.claims.beamline
	input.beamline == session.beamline
}
