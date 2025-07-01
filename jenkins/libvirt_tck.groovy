job('libvirt-tck') {
    description('')

    parameters {
        stringParam('LIBVIRT_TCK_REPO', 'https://gitlab.com/libvirt/libvirt-tck', 'Git repo for libvirt-tck')
        stringParam('LIBVIRT_TCK_BRANCH', 'master', 'Branch to use for libvirt-tck')
    }

    scm {
        // Equivalent to NullSCM (no SCM)
        configure { node ->
            node / 'scm'(
                class: 'hudson.scm.NullSCM'
            )
        }
    }

    steps {
        shell('''
sudo bastille destroy -a testrunner
sudo bastille create testrunner 14.3-RELEASE 10.1.1.4/24
sudo bastille template testrunner novel/libvirt-tck --arg LIBVIRT_TCK_REPO="$LIBVIRT_TCK_REPO" --arg LIBVIRT_TCK_BRANCH="$LIBVIRT_TCK_BRANCH"
sudo bastille cmd testrunner sh -c "cd /root/libvirt-tck && avocado --config avocado.config  run --xunit ./scripts/domain/*.t ./scripts/storage/*.t" || true
sudo bastille rcp testrunner /root/avocado/job-results/latest/ $WORKSPACE/test-results
'''.stripIndent())
    }

    publishers {
        archiveArtifacts('test-results/*')
        archiveXUnit {
            jUnit {
               pattern('test-results/results.xml')
            }
        }
    }
}
