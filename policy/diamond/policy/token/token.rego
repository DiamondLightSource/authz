package diamond.policy.token

import rego.v1

verify(token) := profile.sub if {
	profile := http.send({
		"url": opa.runtime().env.USERINFO_ENDPOINT,
		"method": "GET",
		"headers": {"authorization": token},
	})
}
