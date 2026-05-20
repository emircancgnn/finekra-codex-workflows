# Finekra API Work Instructions

## Credential Handling

- Do not write passwords, tokens, VPN secrets, customer data, or server credentials into this repository.
- Use Vaultwarden/Bitwarden for reusable credentials when it is available.
- Default local Vaultwarden URL: `https://localhost:8080`.
- If Vaultwarden is deployed on server `172.16.220.58`, use `http://172.16.220.58:8080`.
- Default Vaultwarden account email: `emircancgn.35@gmail.com`.
- Do not store the Vaultwarden master password in this repository or in this file.
- Import source for company credentials: the desktop account-info text file matching `HESAP*BILG*` or `HESAP*BILGI*` when normalized for Turkish characters.
- For SSH access to `172.16.220.58`, prefer the vault item named `Server 58 - emircancagin`.
- For Elastic/Kibana access, prefer the vault item named `Elastic - 172.16.220.59`.
- If the vault is unavailable or the item cannot be found, ask the user for the credential at runtime instead of storing it.

## Finekra API Workflow

- Use the project-local skill at `.codex/skills/finekra-api/`.
- Read `.codex/skills/finekra-api/references/finekra-api.md` before preparing or executing Finekra API calls.
- Execute Finekra API calls through `172.16.220.58` over SSH unless the user explicitly asks for a different route.
- Use `.codex/skills/finekra-api/scripts/invoke-finekra-remote.ps1` for repeatable remote calls.
- Show method, URL, headers, and body before execution unless the user explicitly asks to run immediately.
- Ask for confirmation before production side effects such as creating records, updating records, initiating payments, or changing financial state.

## Elastic/Kibana Workflow

- Use Kibana at `http://172.16.220.59:5601/`.
- Use Vaultwarden item `Elastic - 172.16.220.59` for login credentials.
- If Vaultwarden is unavailable, read the Elastic entry from the desktop account-info text file only when needed and do not print the password in chat output.

## Finekra VPN Workflow

- Use FortiClient VPN profile `Finekra` before accessing `172.16.220.0/24` resources such as server `172.16.220.58` and Kibana `172.16.220.59:5601`.
- For VPN connection requests, open FortiClient, go to `Remote Access`, explicitly select `VPN Name = Finekra`, then enter credentials. Do not rely on the profile that is currently selected in FortiClient.
- Use Vaultwarden item `Finekra VPN - polynom.usr09` for the FortiClient username/password.
- If FortiClient asks for a phone token or MFA code, stop and ask the user for the current token.
- After VPN connection, verify access with `Test-NetConnection 172.16.220.58 -Port 22` and `Test-NetConnection 172.16.220.59 -Port 5601`.

## Finekra SQL Read Workflow

- Before SQL work, verify `Test-NetConnection 172.16.220.50 -Port 1433`.
- If SQL is unreachable, connect FortiClient VPN by explicitly selecting VPN profile `Finekra`; wait for the user's phone approval/token if prompted.
- Use Vaultwarden item `Finekra SQL Read - 172.16.220.50` for read-only SQL credentials.
- If Vaultwarden is unavailable, read only the `SQL` section from the desktop account-info file at runtime and do not print the password.
- SQL access is read-only by default. Start with schema discovery and targeted lookup queries; do not run write or job-triggering SQL without explicit confirmation.
