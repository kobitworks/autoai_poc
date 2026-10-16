# Security policy for public PoCs

This repository is **public** and deployed as static experiments via GitHub
Pages. Treat the entire Git history, workflows, binaries and test data as public.

- Do not commit API keys, private keys, secrets, credentials, real customer data,
  personal images or private business records. Test inputs must be synthetic or
  reviewed for explicit publication.
- Browsers on GitHub Pages must not access privileged Cloudflare/Supabase/GitHub
  API tokens. Any future server-side feature requires a separately secured
  backend and scoped tokens.
- Cloudflare provisioning workflows are `workflow_dispatch` only and must be
  started deliberately. Their secrets belong in GitHub Actions secrets; scope
  credentials to the minimum operations needed. Review the provisioning scripts
  and estimated billing impact before invoking them.
- CI build jobs that publish generated artifacts require temporary
  `contents: write`. Protect the `develop` and `main` branches from
  unreviewed pushes and restrict repository collaborator write access.
- The CI credential scan catches high-confidence token formats in tracked
  text, but it does not detect every key type or previously leaked secrets.
  Enable GitHub secret scanning and push protection in repository settings
  when available. If any real secret was committed in the past, revoke it
  immediately; deleting a file does not remove it from Git history.
- Pages does not run a server-side WAF for static assets. Rate limiting, API
  authentication, abuse prevention, and network protection must be enforced at
  the actual API/backend provider; they cannot be added safely by HTML alone.

Report suspected credentials/exposures to maintainers privately, not in public
issues. Do not disclose working tokens in CI logs or security reports.
