# FreeBSD CI configuration for libvirt/bhyve
## Overview

Goal of this project is to create reproducible way of setting up
of a CI instance to run libvirt integration tests on FreeBSD.

This project is sponsored by [The FreeBSD Foundation](https://freebsdfoundation.org/).

Testing is built around the [libvirt-tck](https://gitlab.com/libvirt/libvirt-tck)
project. Tests are executed in a jail managed by BastilleBSD.

## Host setup

Unfortunately, the host setup is not automated yet.

Package installation:

```
# pkg install bastille poudriere jenkins
```

Jenkins needs to be enabled in `rc.conf`:

```
jenkins_enable="YES"
```

BastilleBSD needs to be set up using:

```
# bastille setup
# bastille bootstrap 14.3-RELEASE
```

Poudriere needs to have a ports tree and a jail:

```
# poudriere jail -c -j 14amd64 -v 14.3-RELEASE
# poudriere ports -c
# sudo poudriere ports -c -p libvirt_devel -m git+file -U https://github.com/novel/libvirt-ports-overlay.git
```

In order to let Jenkins run bastille and poudriere,
sudo(8) needs to be configured:

```
Cmnd_Alias      BASTILLE = /usr/local/bin/bastille
Cmnd_Alias      POUDRIERE = /usr/local/bin/poudriere

jenkins ALL=(ALL) NOPASSWD: BASTILLE,POUDRIERE
```

## Jenkins Setup

The [Job DSL](https://plugins.jenkins.io/job-dsl/) plugin is used to define jobs.

Please refer to the plugin's page for information how to create a seed job.

Seed Job params:

 - Add a Git repo, and use URL of this repo: `https://github.com:novel/libvirt-freebsd-ci.git`
 - Process Job DSLs -> Look on Filesystem -> DSL Scripts: `jenkins/*.groovy`

Might consider enabling `Poll SCM`. After running a job, might need approve the new scripts
in `Manage Jenkins / In-process Script Approval`.

## Artifacts

Libvirt-tck needs various artifacts for testing, such as SSH keys and images.
Images are the tricky part as libvirt-tck uses virt-builder(1) to generate images.
virt-builder(1) is a part of libguestfs, and it doesn't support FreeBSD.
It doesn't support FreeBSD as a host system and, additionally, creating FreeBSD
guest images with it also didn't work for me.

Fortunately, the image only needs to be generated once
and can then be reused for subsequent test runs. So it's way simpler
to either re-use a pre-generated image or implement a script
to generate it.

TODO: upload the image somewhere or add a script.

## See also

Repository with the ports overlay: [libvirt-ports-overlay](https://github.com/novel/libvirt-ports-overlay.git)

## TODO

 - Document how (or better create a script) to install Bastille template
   and related files
 - Or even better, implement `prepare_host.sh`?
 - Look into configuring poudiere-queue to allow non-root poudiere
