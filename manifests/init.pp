class puppet-bootstrap {
    Exec {
      path => "/sbin:/bin:/usr/sbin:/usr/bin",
    }

    Package {
      require => Exec["yum clean all"],
    }

    File {
      owner => "root",
      group => "root",
      mode  => "0644",
    }

    # Current Puppet packages won't work if SELinux is enforcing
    if ( $selinux_enforced == "true" ) {
        fail( "SELinux is enforcing" )
    }

    exec { "yum clean all":
        command     => "yum clean all",
        refreshonly => true,
    }

    package { "puppet-server":
        ensure => present,
    }

    package { "httpd":
        ensure => present,
    }

    package { "mod_ssl":
        ensure => present,
    }

    package { "mod_passenger":
        ensure => present,
    }

    file { "/etc/httpd/conf.d/puppetmasterd.conf":
        ensure  => file,
        content => template("puppet-bootstrap/puppetmasterd.conf.erb"),
        require => Package["httpd"],
        notify  => Service["httpd"],
    }

    file { "/srv/www":
        ensure => directory,
    }

    file { "/srv/www/puppet.${domain}":
        ensure  => directory,
        require => File["/srv/www"],
    }

    file { "/srv/www/puppet.${domain}/public":
        ensure  => directory,
        require => File["/srv/www/puppet.${domain}"],
    }

    file { "/srv/www/puppet.${domain}/tmp":
        ensure  => directory,
        require => File["/srv/www/puppet.${domain}"],
    }

    file { "/srv/www/puppet.${domain}/config.ru":
        ensure  => file,
        owner   => "puppet",
        group   => "root",
        source  => "puppet:///modules/puppet-bootstrap/config.ru",
        require => [
            File["/srv/www/puppet.${domain}"],
            File["/srv/www/puppet.${domain}/public"],
            File["/srv/www/puppet.${domain}/tmp"],
            Package["mod_passenger"],
        ],
        notify  => Service["httpd"],
    }

    file { "/etc/puppet/puppet.conf":
        ensure  => file,
        content => template("puppet-bootstrap/puppet.conf.erb"),
        require => Package["puppet-server"],
        notify  => Service["httpd"],
    }

    service { "puppetmaster":
        ensure     => stopped,
        enable     => false,
        hasrestart => true,
        hasstatus  => true,
        require    => [
            Package["puppet-server"],
            File["/etc/puppet/puppet.conf"],
        ],
    }

    # Short of a nice way to get the certificates generated just start up
    # puppetmaster and stop it again
    exec { "puppetmaster-run-once":
        command => "service puppetmaster start && service puppetmaster stop",
        creates => "/var/lib/puppet/ssl/certs/puppet.${domain}.pem",
        require => Service["puppetmaster"],
    }

    service { "httpd":
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        require    => [
            Package["httpd"],
            Package["mod_ssl"],
            Exec["puppetmaster-run-once"],
        ],
    }
}
