# See README.md for usage information
class sssd::config (
  $ensure                  = $sssd::ensure,
  $config                  = $sssd::config,
  $config_file             = $sssd::config_file,
  $config_template         = $sssd::config_template,
  $base_flags              = $sssd::base_flags,
  $mkhomedir               = $sssd::mkhomedir,
  $enable_mkhomedir_flags  = $sssd::enable_mkhomedir_flags,
  $disable_mkhomedir_flags = $sssd::disable_mkhomedir_flags,
  $pam_access               = $sssd::pam_access,
  $enable_pam_access_flags  = $sssd::enable_pam_access_flags,
  $disable_pam_access_flags = $sssd::disable_pam_access_flags,
  $join_ad_domain          = $sssd::join_ad_domain,
  $ad_domain               = $sssd::ad_domain,
  $ad_join_user            = $sssd::ad_join_user,
  $ad_join_pass            = $sssd::ad_join_pass,
) {

  file { 'sssd.conf':
    ensure  => $ensure,
    path    => $config_file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template($config_template),
  }

  case $::osfamily {

    'Redhat': {

      $authconfig_base_flags = join($base_flags, ' ')

      $authconfig_mkhomedir_flags = $mkhomedir ? {
        true  => join($enable_mkhomedir_flags, ' '),
        false => join($disable_mkhomedir_flags, ' '),
      }
      $authconfig_pam_access_flags = $pam_access ? {
        true  => join($enable_pam_access_flags, ' '),
        false => join($disable_pam_access_flags, ' '),
      }

      $authconfig_flags = "${authconfig_base_flags} ${authconfig_mkhomedir_flags} ${authconfig_pam_access_flags}"

      $authconfig_update_cmd = "/usr/sbin/authconfig ${authconfig_flags} --update"
      $authconfig_test_cmd   = "/usr/sbin/authconfig ${authconfig_flags} --test"
      $authconfig_check_cmd  = "/usr/bin/test \"`${authconfig_test_cmd}`\" = \"`/usr/sbin/authconfig --test`\""

      exec { 'authconfig-mkhomedir':
        command => $authconfig_update_cmd,
        unless  => $authconfig_check_cmd,
      }

      if $join_ad_domain {
        package { 'adcli':
          ensure => present,
        }
        exec { 'join-computer-to-domain':
          command => "/bin/echo -n '${ad_join_pass}' |  /usr/sbin/adcli join ${ad_domain} -U ${ad_join_user} --stdin-password",
          creates => '/etc/krb5.keytab',
          require => Package['adcli'],
        }
        Exec[ 'authconfig-mkhomedir' ] -> File[ 'sssd.conf' ] -> Exec[ 'join-computer-to-domain' ]
      }
      else {
        Exec[ 'authconfig-mkhomedir' ] -> File[ 'sssd.conf' ]
      }
    }

    'Debian': {

      if $mkhomedir {

        exec { 'pam-auth-update':
          path        => '/bin:/usr/bin:/sbin:/usr/sbin',
          refreshonly => true,
        }

        file { '/usr/share/pam-configs/pam_mkhomedir':
          ensure => file,
          owner  => 'root',
          group  => 'root',
          mode   => '0644',
          source => "puppet:///modules/${module_name}/pam_mkhomedir",
          notify => Exec['pam-auth-update'],
        }

      }

    }

    default: { }

  }

}
