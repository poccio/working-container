#!/bin/bash
set -euo pipefail
source /opt/bash-utils/logger.sh

# https://github.com/moby/moby/blob/38805f20f9bcc5e87869d6c79d432b166e1c88b4/hack/dind#L28-L38
# cgroup v2: enable nesting. Must happen before dockerd starts, so it sees the
# controllers when it probes them at startup.
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
	INFO "Enabling cgroup v2 nesting"
	# move the processes from the root group to the /init group,
	# otherwise writing subtree_control fails with EBUSY.
	# An error during moving non-existent process (i.e., "cat") is ignored.
	mkdir -p /sys/fs/cgroup/init
	xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs || :
	# enable controllers
	sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
		> /sys/fs/cgroup/cgroup.subtree_control
fi

# supervisord becomes PID 1: it reaps children, forwards SIGTERM on `docker stop`,
# and (in nodaemon mode) mirrors its own log to stdout so it shows in `docker logs`.
# dockerd and sshd are defined in /etc/supervisor/conf.d/.
INFO "Starting supervisord"
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
