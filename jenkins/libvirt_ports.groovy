job('libvirt-ports-overlay') {
    description('')

    scm {
        git {
            remote {
                url('https://github.com/novel/libvirt-ports-overlay.git')
            }
            branch('*/master')
        }
    }

    triggers {
        scm('H(0-59) H(3-5) * * *\nH(0-59) H(15-17) * * *')
    }

    wrappers {
        timestamps()
    }

    steps {
        shell('''
sudo poudriere ports -p libvirt_devel -u
sudo /usr/local/bin/poudriere bulk -C -j 14amd64 -O libvirt_devel -t devel/libvirt-devel devel/p5-Sys-Virt-devel
'''.stripIndent())
    }

    publishers {
        downstream('libvirt-tck', 'SUCCESS')
    }
}
