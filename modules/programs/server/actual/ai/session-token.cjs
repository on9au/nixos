// actual-ai only logs in with a password, which budget.opena0.net doesn't
// accept. @actual-app/api takes a session token instead, so swap one in: the
// unit mints it before the run and deletes it after (see default.nix).
const api = require(require.resolve("@actual-app/api", {paths: ["/opt/node_app/app"]}));
const init = api.init;

api.init = ({password, ...config}) =>
  init({...config, sessionToken: process.env.ACTUAL_SESSION_TOKEN});
