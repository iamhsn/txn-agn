# Working on txn-agn from Hassan's desktop

Read `docs/HANDOFF.md` (current state, next steps) and `docs/RUNBOOK.md` (how things work) before doing anything.

## Where things run
- This folder is a local clone of the public repo `iamhsn/txn-agn`. The live copy is `/opt/txn-agn` on the server.
- The server is reachable only over Tailscale. Run every server command through SSH:
  `ssh root@txn-agn '<command>'`
  If SSH asks Hassan to approve in a browser, that is Tailscale's check; wait for him.
- Agent-side commands run as the `agent` user:
  `ssh root@txn-agn "sudo -u agent env HOME=/home/agent XDG_RUNTIME_DIR=/run/user/2000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/2000/bus PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin bash -c '<command>'"`
- Web UIs (Tailscale must be on): n8n editor `https://txn-agn.tailc354f1.ts.net/`, Paperclip `https://txn-agn.tailc354f1.ts.net:8443/`.

## Making changes
- Edit and commit here, then ask Hassan before `git push` (the repo is public). After a push, deploy with `ssh root@txn-agn 'cd /opt/txn-agn && git pull --ff-only'`.
- Never commit `.env` files, keys or tokens. Never print secret values; compare or show lengths instead.

## Rules
- Hassan is not a terminal user. Say in one line what each command does before running it.
- Ask before touching the client lead workflows in n8n, the Cloudflare tunnel or the `txn-lead-buffer` Worker.
- Keep the `agent` user at uid 2000, without sudo or docker. Never use `pkill -u` or `killall` on the server.
- Prefer read-only checks first. Anything that restarts a service or changes data: say so and wait for a yes.
