package diamond.policy.token

import rego.v1

verify_cas(token) := profile.sub if {
	profile := http.send({
		"url": opa.runtime().env.USERINFO_ENDPOINT,
		"method": "GET",
		"headers": {"authorization": token},
	})
}

verify_keycloak(token) := claims if {

    fetch_jwks(url) := http.send({
        "url": jwks_url,
        "method": "GET",
        "force_cache": true,
        "force_cache_duration_seconds": 86400,
    })

    jwks_endpoint := opa.runtime().env.JWKS_ENDPOINT

    unverified := io.jwt.decode(token)

    jwt_header := unverified[0]

    jwks_url := concat("?", [jwks_endpoint, urlquery.encode_object({"kid": jwt_header.kid})])

    jwks := fetch_jwks(jwks_url).raw_body

    valid := io.jwt.decode_verify(token, {
        "cert": jwks,
        "iss": "https://authn.diamond.ac.uk/realms/master",
        "aud": "account",
    })

    claims := valid[2]

}

verify if verify_cas(input.token)
verify if verify_keycloak(input.token)
