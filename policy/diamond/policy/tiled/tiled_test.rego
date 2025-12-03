package diamond.policy.tiled_test

import data.diamond.policy.tiled
import data.diamond.policy.token
import rego.v1

test_default_no_scopes if {
	tiled.scopes == set()
}

test_wrong_azp_read_scopes if {
	tiled.scopes == tiled.read_scopes with token.claims as {}
	tiled.scopes == tiled.read_scopes with token.claims as {"sub": "foo"}
	tiled.scopes == tiled.read_scopes with token.claims as {"azp": "foo"}
}

test_blueapi_given_write_scopes if {
	tiled.scopes == {
		"read:metadata",
		"read:data",
		"write:metadata",
		"write:data",
		"create",
		"register",
	} with token.claims as {"azp": "foo-blueapi"}
}
