$apache_doc_root = "/var/www/html"

$drupal_dl_name = "drupal"
$drupal_db_usr = "%{dbuser}"
$drupal_db_pass = "%{dbpass}"
$drupal_db_name = "%{dbname}"
$drupal_db_host = "%{dbhost}"
$drupal_db_port = "%{dbport}"
$drupal_admin_pass = "%{drupal_admin_pass}"

# execute 'apt-get update'
exec { 'apt-update':
	command => '/usr/bin/apt-get update'
}

# install apache2 package
class { 'apache':
	mpm_module => 'prefork',
	docroot => $apache_doc_root
 }
include apache::mod::php
include apache::mod::rewrite

apache::vhost { 'example.com':
	port    => '80',
	docroot => $apache_doc_root,
	directories => [ { path => $apache_doc_root, allow_override => ['All'] } ]
}

# ensure info.php file exists
file { "${apache_doc_root}/info.php":
	ensure => file,
	content => '<?php  phpinfo(); ?>',
	require => Package['apache2']
}

# install php5 modules required by drupal
package { 'php5-gd':
	require => Exec['apt-update'],
	ensure => installed
}

# install php5 modules required by drupal
package { 'php5-curl':
	require => Exec['apt-update'],
	ensure => installed
}

# install php5 modules required by drupal
package { 'libssh2-php':
	require => Exec['apt-update'],
	ensure => installed
}

file {'/etc/php5/apache2/conf.d/drupal_specific.conf':
	require => Package['libssh2-php'],
	ensure => file,
	owner => root, group => root, mode => 444,
	content => "expose_php = Off\nallow_url_fopen = Off"
}

# install drush
# todo refactor
package { 'drush':
	require => Package['apache2']
}

exec{ 'download-drupal':
	require => Package['drush'],
	command => "/usr/bin/drush dl drupal --destination='/tmp' --drupal-project-rename='${drupal_dl_name}'"
}

exec{ 'copy-drupal-to-apache':
	require => Exec['download-drupal'],
	command => "/bin/cp -r /tmp/${drupal_dl_name} ${apache_doc_root}"
}

exec{ 'install-drupal':
	require => Exec['copy-drupal-to-apache'],
	command => "/usr/bin/drush -y site-install standard --db-url='mysql://${drupal_db_usr}:${drupal_db_pass}@${drupal_db_host}:${drupal_db_port}/${drupal_db_name}' --site-name=Example --account-pass=${drupal_admin_pass}",
	cwd => "${apache_doc_root}/${drupal_dl_name}"
}