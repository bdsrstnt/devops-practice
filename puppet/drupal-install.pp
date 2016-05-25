$apache_doc_root = '/var/www/html'
$php_conf_root = '/etc/php5/apache2/conf.d'
$drupal_dl_name = 'drupal'
$drush = '/usr/bin/drush'
$drush_db_url = "mysql://${drupal_db_user}:${drupal_db_pass}@${drupal_db_host}:${drupal_db_port}/${drupal_db_name}"

# execute 'apt-get update'
exec { 'apt-update':
  command => '/usr/bin/apt-get update'
}

# install apache2 package
class { 'apache':
  mpm_module    => 'prefork',
  docroot       => $apache_doc_root,
  default_vhost => false
}

#install php module
include apache::mod::php

#enable rewrite on apache
include apache::mod::rewrite

# configure the vhost
apache::vhost { 'drupal':
  port        => '80',
  docroot     => $apache_doc_root,
  directories => [ {
    path           => $apache_doc_root,
    allow_override => ['All']
  } ]
}

# install php5 modules required by drupal
package { 'php5-gd':
  ensure  => installed,
  require => Exec['apt-update']
}

# install php5 modules required by drupal
package { 'php5-curl':
  ensure  => installed,
  require => Exec['apt-update']
}

# install php5 modules required by drupal
package { 'libssh2-php':
  ensure  => installed,
  require => Exec['apt-update']
}

# adding drupal specific php config override
file {"${php_conf_root}/drupal_specific.ini":
  ensure  => file,
  require => Package['libssh2-php'],
  owner   => root,
  group   => root,
  mode    => '0444',
  content => "expose_php = Off\nallow_url_fopen = Off"
}

# install drush
package { 'drush':
  require => Package['apache2']
}

# remove drupal dir from apache if exists
exec { 'purge-drupal-from-apache':
  command => "/bin/rm -r ${apache_doc_root}/${drupal_dl_name}",
  onlyif  =>  ["/usr/bin/test -d ${apache_doc_root}/${drupal_dl_name}"],
  before  => Exec['copy-drupal-to-apache']
}

# download drupal
exec { 'download-drupal':
  require => Package['drush'],
  command => "${drush} dl drupal --destination='/tmp' --drupal-project-rename='${drupal_dl_name}'"
}

# copy the downloaded drupal to the apache docroot
exec { 'copy-drupal-to-apache':
  require => Exec['download-drupal'],
  command => "/bin/cp -r /tmp/${drupal_dl_name} ${apache_doc_root}"
}

# cleanup drupal download
exec { 'purge-drupal-download':
  require => Exec['copy-drupal-to-apache'],
  command => "/bin/rm -r /tmp/${drupal_dl_name}"
}

# install drupal with drush
exec { 'install-drupal':
  require => Exec['copy-drupal-to-apache'],
  command => "${drush} -y si --db-url='${drush_db_url}' --site-name=${drupal_site_name} --account-pass=${drupal_admin_pass}",
  cwd     => "${apache_doc_root}/${drupal_dl_name}"
}

# set group for /var/www/html to www-data
exec { 'chown-www-data':
  require => Exec['install-drupal'],
  command => "/bin/chown -R :www-data ${apache_doc_root}"
}

# make sites/default
exec { 'chmod-files':
  require => Exec['chown-www-data'],
  command => "/bin/chmod -R 664 ${apache_doc_root}/${drupal_dl_name}/sites/default"
}

# set lock settings.php
exec { 'chmod-www-data':
  require => Exec['chmod-files'],
  command => "/bin/chmod -R 644 ${apache_doc_root}/${drupal_dl_name}/sites/default/settings.php"
}

# restart apache
exec {'restart-apache':
  require => Exec['install-drupal'],
  command => '/usr/bin/service apache2 restart'
}
