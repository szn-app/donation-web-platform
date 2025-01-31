// example from https://github.com/shaninalex/angular-go-kratos-ui/blob/main/config/kratos/google.jsonnet
// https://developers.google.com/identity/openid-connect/openid-connect#an-id-tokens-payload
local claims = {
  email_verified: true,
} + std.extVar('claims');

{
  identity: {
    traits: {
      [if 'email' in claims && claims.email_verified then 'email' else null]: claims.email,
      name: claims.name,
      // image: claims.picture
    },
  },
}