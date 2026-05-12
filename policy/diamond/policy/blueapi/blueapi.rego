package diamond.policy.blueapi

import data.diamond.policy.token
import rego.v1

default service_account_for_beamline := false

service_account_for_beamline if {
	input.beamline == token.claims.beamline
	"tiled-writer" in token.claims.aud
	not token.claims.fedid
}
