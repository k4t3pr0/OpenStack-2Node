#!/bin/bash

# Set environment variables
CONTROLLER_HOST=controller.example.com
COMPUTE_HOST=compute.example.com
ADMIN_PASS=your_admin_pass
DEMO_PASS=your_demo_pass
RABBIT_PASS=your_rabbit_pass
MYSQL_PASS=your_mysql_pass
PLACEMENT_PASS=your_placement_pass
NOVA_PASS=your_nova_pass
NEUTRON_PASS=your_neutron_pass
DASHBOARD_PASS=your_dashboard_pass

# Update system and install necessary packages
sudo apt update
sudo apt install -y chrony

# Install and configure MariaDB
sudo apt install -y mariadb-server python3-pymysql
sudo mysql_secure_installation

# Install and configure RabbitMQ
sudo apt install -y rabbitmq-server
sudo rabbitmqctl add_user openstack $RABBIT_PASS
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# Install Keystone
sudo apt install -y keystone

# Configure Keystone
sudo cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
sudo crudini --set /etc/keystone/keystone.conf database connection 'mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone'
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone
sudo keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$CONTROLLER_HOST:5000/v3/ \
  --bootstrap-internal-url http://$CONTROLLER_HOST:5000/v3/ \
  --bootstrap-public-url http://$CONTROLLER_HOST:5000/v3/ \
  --bootstrap-region-id RegionOne
sudo apt install -y python3-openstackclient apache2 libapache2-mod-wsgi-py3
sudo service apache2 restart

# Install Glance
sudo apt install -y glance

# Configure Glance
sudo cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
sudo crudini --set /etc/glance/glance-api.conf database connection 'mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers '$CONTROLLER_HOST:11211'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type 'password'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name 'Default'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name 'Default'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name 'service'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken username 'glance'
sudo crudini --set /etc/glance/glance-api.conf keystone_authtoken password '$GLANCE_PASS'
sudo crudini --set /etc/glance/glance-api.conf paste_deploy flavor 'keystone'
sudo su -s /bin/sh -c "glance-manage db_sync" glance

# Install and configure Nova
sudo apt install -y nova-api nova-conductor nova-novncproxy nova-scheduler
sudo apt install -y nova-compute

# Configure Nova
sudo cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
sudo crudini --set /etc/nova/nova.conf database connection 'mysql+pymysql://nova:$NOVA_DBPASS@controller/nova'
sudo crudini --set /etc/nova/nova.conf api_database connection 'mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api'
sudo crudini --set /etc/nova/nova.conf DEFAULT transport_url 'rabbit://openstack:$RABBIT_PASS@controller'
sudo crudini --set /etc/nova/nova.conf DEFAULT my_ip '$COMPUTE_HOST'
sudo crudini --set /etc/nova/nova.conf DEFAULT use_neutron 'true'
sudo crudini --set /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'
sudo crudini --set /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken auth_url 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers '$CONTROLLER_HOST:11211'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken auth_type 'password'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name 'Default'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name 'Default'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken project_name 'service'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken username 'nova'
sudo crudini --set /etc/nova/nova.conf keystone_authtoken password '$NOVA_PASS'
sudo crudini --set /etc/nova/nova.conf vnc enabled 'true'
sudo crudini --set /etc/nova/nova.conf vnc server_listen '$COMPUTE_HOST'
sudo crudini --set /etc/nova/nova.conf vnc server_proxyclient_address '$COMPUTE_HOST'
sudo crudini --set /etc/nova/nova.conf glance api_servers 'http://$CONTROLLER_HOST:9292'
sudo crudini --set /etc/nova/nova.conf oslo_concurrency lock_path '/var/lib/nova/tmp'
sudo crudini --set /etc/nova/nova.conf placement region_name 'RegionOne'
sudo crudini --set /etc/nova/nova.conf placement project_domain_name 'Default'
sudo crudini --set /etc/nova/nova.conf placement project_name 'service'
sudo crudini --set /etc/nova/nova.conf placement auth_type 'password'
sudo crudini --set /etc/nova/nova.conf placement user_domain_name 'Default'
sudo crudini --set /etc/nova/nova.conf placement auth_url 'http://$CONTROLLER_HOST:5000/v3'
sudo crudini --set /etc/nova/nova.conf placement username 'placement'
sudo crudini --set /etc/nova/nova.conf placement password '$PLACEMENT_PASS'
sudo su -s /bin/sh -c "nova-manage api_db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
sudo su -s /bin/sh -c "nova-manage db sync" nova

# Install and configure Neutron
sudo apt install -y neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
sudo apt install -y neutron-openvswitch-agent

# Configure Neutron
sudo cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
sudo crudini --set /etc/neutron/neutron.conf database connection 'mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron'
sudo crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin 'ml2'
sudo crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ''
sudo crudini --set /etc/neutron/neutron.conf DEFAULT transport_url 'rabbit://openstack:$RABBIT_PASS@controller'
sudo crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url 'http://$CONTROLLER_HOST:5000'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers '$CONTROLLER_HOST:11211'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type 'password'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name 'Default'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name 'Default'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name 'service'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken username 'neutron'
sudo crudini --set /etc/neutron/neutron.conf keystone_authtoken password '$NEUTRON_PASS'
sudo crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path '/var/lib/neutron/tmp'

sudo cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'flat,vlan,vxlan'
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types ''
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers 'linuxbridge'
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers 'port_security'
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks 'provider'
sudo crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset 'true'

sudo cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
sudo crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings 'provider:$PROVIDER_INTERFACE_NAME'
sudo crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan 'false'
sudo crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group 'true'
sudo crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver'

sudo cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
sudo crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver 'linuxbridge'

sudo cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
sudo crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'linuxbridge'
sudo crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
sudo crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata 'true'

sudo cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.bak
sudo crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host '$CONTROLLER_HOST'
sudo crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret '$METADATA_SECRET'

sudo su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

# Install and configure Dashboard (Horizon)
sudo apt install -y openstack-dashboard
sudo cp /etc/openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py.bak
sudo crudini --set /etc/openstack-dashboard/local_settings.py 'ALLOWED_HOSTS' "'$CONTROLLER_HOST'"
sudo service apache2 reload

# Completion
echo "OpenStack installation completed!"
