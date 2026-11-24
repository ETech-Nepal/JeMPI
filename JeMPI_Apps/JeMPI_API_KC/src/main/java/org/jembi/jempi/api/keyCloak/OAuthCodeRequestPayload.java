package org.jembi.jempi.api.keyCloak;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

// Keycloak 22+ also returns `iss` (RFC 9207) in the redirect; the UI forwards every parameter.
@JsonIgnoreProperties(ignoreUnknown = true)
@JsonInclude(JsonInclude.Include.NON_NULL)
public record OAuthCodeRequestPayload(
      @JsonProperty("code") String code,
      @JsonProperty("state") String state,
      @JsonProperty("session_state") String sessionId) {
}
