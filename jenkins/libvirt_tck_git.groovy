job('libvirt-tck-git') {
    description('')

    parameters {
        stringParam('LIBVIRT_TCK_REPO', 'https://gitlab.com/libvirt/libvirt-tck', 'Git repo for libvirt-tck')
        stringParam('LIBVIRT_TCK_BRANCH', 'master', 'Branch to use for libvirt-tck')
        stringParam('LIBVIRT_REPO', 'https://gitlab.com/libvirt/libvirt', 'Git repo for libvirt')
        stringParam('LIBVIRT_BRANCH', 'master', 'Branch to use for libvirt')
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
sudo bastille destroy -y -a testrunner-git
sudo bastille create testrunner-git 14.3-RELEASE DHCP virbr0
sudo bastille template testrunner-git novel/libvirt-tck-git --arg LIBVIRT_TCK_REPO="$LIBVIRT_TCK_REPO" --arg LIBVIRT_TCK_BRANCH="$LIBVIRT_TCK_BRANCH --arg LIBVIRT_REPO="$LIBVIRT_REPO" --arg LIBVIRT_BRANCH="$LIBVIRT_BRANCH"
sudo bastille cmd testrunner-git sh -c "cd /root/libvirt-tck && avocado --config avocado.config  run --xunit ./scripts/domain/*.t ./scripts/storage/*.t ./scripts/networks/*.t ./scripts/hooks/*.t" || true
sudo bastille rcp testrunner-git /root/avocado/job-results/latest/ $WORKSPACE/test-results
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
