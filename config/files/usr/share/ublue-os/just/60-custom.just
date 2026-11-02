import '82-hyperblue-waydroid.just'

# Re-run Hyperblue's per-user setup (it normally runs automatically on first login)
[group('Hyperblue')]
re-run-hyperblue-setup:
    #!/usr/bin/bash
    exec hyperblue setup --force

# Show which per-user setup steps have completed
[group('Hyperblue')]
hyperblue-status:
    #!/usr/bin/bash
    exec hyperblue status