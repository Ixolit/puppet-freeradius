# Configure SQL support for FreeRADIUS
define freeradius::sql (
  Enum['mysql', 'mssql', 'oracle', 'postgresql'] $database,
  String $password,
  Optional[String] $server                       = 'localhost',
  Optional[String] $login                        = 'radius',
  Optional[String] $radius_db                    = 'radius',
  Freeradius::Integer $num_sql_socks             = "\${thread[pool].max_servers}",
  Optional[String] $query_file                   = "\${modconfdir}/\${.:name}/main/\${dialect}/queries.conf",
  Optional[String] $custom_query_file            = undef,
  Optional[Integer] $lifetime                    = 0,
  Optional[Integer] $max_queries                 = 0,
  Freeradius::Ensure $ensure                     = present,
  Optional[String] $acct_table1                  = 'radacct',
  Optional[String] $acct_table2                  = 'radacct',
  Optional[String] $postauth_table               = 'radpostauth',
  Optional[String] $authcheck_table              = 'radcheck',
  Optional[String] $authreply_table              = 'radreply',
  Optional[String] $groupcheck_table             = 'radgroupcheck',
  Optional[String] $groupreply_table             = 'radgroupreply',
  Optional[String] $usergroup_table              = 'radusergroup',
  Freeradius::Boolean $deletestalesessions       = 'yes',
  Freeradius::Boolean $sqltrace                  = 'no',
  Optional[String] $sqltracefile                 = "\${logdir}/sqllog.sql",
  Optional[Integer] $connect_failure_retry_delay = 60,
  Optional[String] $nas_table                    = 'nas',
  Freeradius::Boolean $read_groups               = 'yes',
  Optional[Integer] $port                        = 3306,
  Freeradius::Boolean $readclients               = 'no',
  Optional[Integer] $pool_start                  = 1,
  Optional[Integer] $pool_min                    = 1,
  Optional[Integer] $pool_spare                  = 1,
  Optional[Integer] $pool_idle_timeout           = 60,
) {
  $fr_package          = $::freeradius::params::fr_package
  $fr_service          = $::freeradius::params::fr_service
  $fr_basepath         = $::freeradius::params::fr_basepath
  $fr_modulepath       = $::freeradius::params::fr_modulepath
  $fr_group            = $::freeradius::params::fr_group
  $fr_logpath          = $::freeradius::params::fr_logpath
  $fr_moduleconfigpath = $::freeradius::params::fr_moduleconfigpath

  # Validate our inputs
  # Hostnames
  unless (is_domain_name($server) or is_ip_address($server)) {
    fail('$server must be a valid hostname or IP address')
  }

  # Validate integers
  unless is_integer($num_sql_socks) or $num_sql_socks == "\${thread[pool].max_servers}" {
    fail('$num_sql_socks must be an integer')
  }

  # Determine default location of query file
  $queryfile = "${fr_basepath}/sql/queries.conf"

  # Install custom query file
  if ($custom_query_file and $custom_query_file != '') {
    $custom_query_file_path = "${fr_moduleconfigpath}/${name}-queries.conf"

    ::freeradius::config { "${name}-queries.conf":
      source => $custom_query_file,
    }
  }

  # Generate a module config, based on sql.conf
  file { "${fr_basepath}/mods-available/${name}":
    ensure  => $ensure,
    mode    => '0640',
    owner   => 'root',
    group   => $fr_group,
    content => template('freeradius/sql.conf.erb'),
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }
  file { "${fr_modulepath}/${name}":
    ensure => link,
    target => "../mods-available/${name}",
  }

  # Install rotation for sqltrace if we are using it
  if ($sqltrace == 'yes') {
    logrotate::rule { 'sqltrace':
      path         => "${fr_logpath}/${sqltracefile}",
      rotate_every => 'week',
      rotate       => 1,
      create       => true,
      compress     => true,
      missingok    => true,
      postrotate   => "kill -HUP `cat ${freeradius::fr_pidfile}`",
    }
  }
}
