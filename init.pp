# == Class: aas_nagios
#
# Common bundle for all nodes in the project.
#

class aas_nagios::nagios_server (  
$nagioscontact=lookup('nagioscontact'),
) 
{


  exec { "Nagios-Service":
    command   => 'service nagios restart;',
    path      => ['/usr/bin','/usr/sbin','/bin','/sbin'],
  }
  
  
  # --------------------------------------
  # Install Nagios Server

  exec { 'install Nagios':
    command => 'rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm; rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm; yum -y install nagios nagios-plugins-all nagios-plugins-nrpe nrpe; chkconfig nagios on; service nagios start; touch /etc/nagios/ninstall_chk',
    path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    onlyif  => "test ! -f /etc/nagios/ninstall_chk",
  } 

  # --------------------------------------
  # Configure Nagios Swap space

  exec { 'install Nagios Swap Space':
    command => 'dd if=/dev/zero of=/swap bs=1024 count=2097152; mkswap /swap && chown root. /swap && chmod 0600 /swap && swapon /swap; yecho /swap swap swap defaults 0 0 >> /etc/fstab; echo vm.swappiness = 0 >> /etc/sysctl.conf && sysctl -p;',
    path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    #onlyif  => "test ! -f /etc/nagios/nswap_chk",
  } 

  # Deploying nagios conf in httpd conf folder

  file { '/etc/httpd/conf.d/nagios.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('aas_nagios/server/nagios_conf.erb'),
  }

  # Deploying Nagios Contacts conf file in /etc/nagios/objects folder

  file { '/etc/nagios/objects/contacts.cfg':
    ensure  => file,
    owner   => 'nagios',
    group   => 'nagios',
    mode    => '0644',
    content => template('aas_nagios/server/nagios_contact.erb'),
  }

  # Deploying Nagios Commands conf file in /etc/nagios/objects folder
  
  file { '/etc/nagios/objects/commands.cfg':
    ensure  => file,
    owner   => 'nagios',
    group   => 'nagios',
    mode    => '0644',
    content => template('aas_nagios/server/nagios_command.erb'),
  }
  
  # Nagios Host Sanity Check File
  
  file { '/opt/admincloud/nagios_host_add.py':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('aas_nagios/server/nagios_host_add.erb'),
  }
  
  # cronjob for  Host Sanity Check
  cron { 'Nagios Sanity Check':
    command => '/opt/admincloud/nagios_host_add.py 2>&1 >& /dev/null',
    user    => 'root', 
    minute  => [25,50],
  }


  
  
  # Setting Admin Password
 
  exec { 'Set Nagios Admin pass':
    command     => 'htpasswd -c -b  /etc/nagios/passwd nagiosadmin btmor499; touch /etc/nagios/pwd_chk',
    onlyif      => "test ! -f /etc/nagios/pwd_chk",
    notify      => Service['httpd'],
    path        => ['/usr/bin','/usr/sbin','/bin','/sbin'],
  } 

  file { '/etc/nagios/servers/': 
    ensure => 'directory',  
  }


  file_line { "nagios_conf1":
    path   => "/etc/nagios/nagios.cfg",
    ensure => present,
    match  => "#cfg_dir=/etc/nagios/servers",
    line   => "cfg_dir=/etc/nagios/servers",
  } 

  file_line { "nagios_conf2":
    path   => "/etc/nagios/nagios.cfg",
    ensure => present,
    match  => "enable_flap_detection=1",
    line   => "enable_flap_detection=0",
  }
 
 $masterip1 = generate ("/bin/bash", "-c", "/usr/bin/gcloud compute addresses describe ts-mgmt1 --region=us-central1 --format=flattened --format='value(address)' | /usr/bin/awk 'FNR == 1 {print \$0}' ")
 $masterip = chomp($masterip1)
  
  
 
  $default_checks = [
    'check_load',
    'check_disk',
    'check_ssh',
    'check_procs',
    'check_procsD',
    'check_procsZ',
    'check_crond',
    'check_rsyslogd',
    'check_nrpe',
    'check_postfix',
    ]
 
         # create nagios check in servers/host file 
  #keys($nagiosconfig).each |String $host_name| {
  #  $host = keys($nagiosconfig[$host_name])
  #    $host.each |String $host_ip| {
  #      $all_checks = unique(concat($default_checks, $nagiosconfig[$host_name][$host_ip]['nagios']))
  #        file { "${host_name}":
  #          path => "/etc/nagios/servers/${host_name}.cfg",
  #          ensure  => file,
  #          owner   => 'nagios',
  #          group   => 'nagios',
  #          mode    => '0755',
  #          content => template("aas_nagios/server/nagios_client.erb"),
  #          notify      => Exec['Nagios-Service'],
  #        } 
  #    }   
  #}
   
  
  exec { 'Set Nagios folder permission':
    command     => 'chown -R nagios. /etc/nagios',
    #onlyif      => "test ! -f /etc/nagios/pwd_chk",
    notify      => Exec['Nagios-Service'],
    path        => ['/usr/bin','/usr/sbin','/bin','/sbin'],
  } 
  
   service { 'nagios':
    ensure => 'running',
  }
  
   

} 





class aas_nagios::nagios_client
{

  exec { "NRPE-Service":
    command   => 'service nrpe restart;',
    path      => ['/usr/bin','/usr/sbin','/bin','/sbin'],
 }
 
  $ipaddr = "${facts['networking']['ip']}"
  
  # -----------------------------------------
  # Install Nagios Client

  exec { 'install Nagios Client':
    command     => 'rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm; rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm; yum -y install nagios nagios-plugins-all nagios-plugins-nrpe nrpe; chkconfig nrpe on; touch /etc/nagios/nrpe_chk',
    path        => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    onlyif      => "test ! -f /etc/nagios/nrpe_chk",
  } 
 
  $monitorip1 = generate ("/bin/bash", "-c", "/usr/bin/gcloud compute addresses describe ts-mgmt1 --region=us-central1 --format=flattened --format='value(address)' | /usr/bin/awk 'FNR == 1 {print \$0}' ")
  $monitorip = chomp($monitorip1)

   
  exec { 'Setup firewall rules for nrpe':
    command      => "iptables -N NRPE; iptables -I INPUT -s 0/0 -p tcp --dport 5666 -j NRPE; iptables -I NRPE -s $monitorip  -j ACCEPT; iptables -A NRPE -s 0/0 -j DROP;/etc/init.d/iptables save; service nrpe start; touch /etc/nagios/nrpeip_chk",
    path         => ['/usr/bin','/usr/sbin','/bin','/sbin'],
    onlyif       => "test ! -f /etc/nagios/nrpeip_chk",
  } 
 
 
  file { '/etc/nagios/nrpe.cfg':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('aas_nagios/client/nrpe_client.erb'),
    notify      => Exec['NRPE-Service'],
  }
  
  service { 'nrpe':
    ensure => 'running',
  }
  

  # --------------------------------------------------------------------------
  # Add any additional items *below* this comment block.
  # --------------------------------------------------------------------------

}