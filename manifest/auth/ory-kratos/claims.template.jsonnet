// https://www.ory.sh/docs/identities/session-to-jwt-cors#end-to-end-example

local claims = std.extVar('claims');
local session = std.extVar('session');

{
  claims: {
    iss: claims.iss + "/additional-component",
    schema_id: session.identity.schema_id,
    session: session,
  }
}