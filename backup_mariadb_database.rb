# Prerequisite: linode-cli
# https://github.com/linode/linode-cli
# See also https://www.linode.com/community/questions/18752/linode-cli-restore-a-backup-to-a-new-linode

# This script lets you generate a dashboard.sql database dump from a Linode snapshot backup of the mariadb node.
# We can rely on the snapshots as our primary backup mechanism, and use this to make occasional copies of the
# database that are independent of the node itself (since the backups will be destroyed along with the node).

# We can also 'imageize' a backup disk after replicating it to a new node, in order to provide a persistent
# backup that is independent of the node.


require 'json'
require 'open3'

MARIADB_SERVER = 'nomad-mariadb-node'
BACKUP_NODE_LABEL = 'MariaDB-Backup'

def refresh_linodes
  @linodes = JSON.parse(`linode-cli linodes list --json`)
  @db_node = @linodes.find { |node| node["label"] == MARIADB_SERVER }
  @backup_node = @linodes.find { |node| node["label"] == BACKUP_NODE_LABEL }
end

def wait_for(node_label, desired_status)
  refresh_linodes
  node = @linodes.find { |node| node["label"] == node_label }
  old_status = node["status"]
  new_status = nil

  until node["status"] == desired_status do
    if old_status == new_status
      print '.'
    else
      puts "#{node_label} is #{node["status"]}"
      print "waiting..."
    end
    sleep 5
    old_status = node["status"]
    refresh_linodes
    node = @linodes.find { |node| node["label"] == node_label }
    new_status = node["status"]
  end
  puts "#{node_label} is #{node["status"]}"
end

def execute_command_on_backup(cmd)
  puts "Executing: #{cmd}"
  ssh_command = "ssh -o StrictHostKeyChecking=no root@#{@backup_node["ipv4"].first} #{cmd}"
  Open3.popen2e(ssh_command) do |stdin, stdout_err, wait_thr|
    while line = stdout_err.gets
      puts line
    end
  
    exit_status = wait_thr.value
    unless exit_status.success?
      abort "FAILED !!! #{cmd}"
    end
  end
end

# Find the mariadb node and get its metadata
refresh_linodes
puts "Found MariaDB node. ID: #{@db_node["id"]}. Type: #{@db_node["type"]}"

# Find the backups for the mariadb node and get the most recent
backups = JSON.parse(`linode-cli linodes backups-list #{@db_node["id"]} --json`)
# Backups are listed newest to oldest
latest_backup = backups.first
puts "Found newest backup:"
puts latest_backup
latest_backup_id = latest_backup["id"]

# Create a new node to load the backup onto
if @backup_node
  puts "Found existing backup node. ID: #{@backup_node["id"]}"
else
  root_pass = ('a'..'z').to_a.sample(12).join # random root password
  puts "Creating a new node..."
  puts "root_pass: #{root_pass}"
  create_node_result = `linode-cli linodes create --type #{@db_node["type"]} --label MariaDB-Backup --root_pass #{root_pass}`
  puts create_node_result
end

# Wait for backup node to finish provisioning and start up
wait_for(BACKUP_NODE_LABEL, 'running')

# Restore the backup on to the new node
# linode-cli linodes backup-restore originalLinodeID backupIDtoRestore --linode_id newLinodeID --overwrite true
puts "Initiating backup-restore..."
backup_result = `linode-cli linodes backup-restore #{@db_node["id"]} #{latest_backup_id} --linode_id #{@backup_node["id"]} --overwrite true`
puts backup_result

wait_for(BACKUP_NODE_LABEL, 'restoring')
wait_for(BACKUP_NODE_LABEL, 'offline')

# Boot the backup node into rescue mode so the consul service doesn't start
disks = JSON.parse(`linode-cli linodes disks-list #{@backup_node["id"]} --json`)
# The root disk should be the only ext4 disk
root_disk = disks.find { |d| d["filesystem"] == 'ext4'}
puts "Booting into rescue mode with disk #{root_disk["id"]} mounted"
boot_rescue_result = `linode-cli linodes rescue #{@backup_node["id"]} --devices.sda.disk_id #{root_disk["id"]}`
puts boot_rescue_result
wait_for(BACKUP_NODE_LABEL, 'running')


LISH_INSTRUCTIONS = <<~LISH
  The backup node is running in rescue mode. The consul service needs to be disabled, and this can only be done
  from the web-based LISH console launched from linode.com. (It may take a few minutes before LISH is ready.)

  Find the backup node (#{BACKUP_NODE_LABEL}) from the Linode dashboard, launch the LISH console, and do the following:
  1. Mount the root disk:
    mkdir -p /media/sda
    mount -o barrier=0 /dev/sda /media/sda
  2. Remove the service entry
    rm /media/sda/etc/systemd/system/consulclient.service

  Consul service disabled and ready to continue? (y)
LISH

puts LISH_INSTRUCTIONS
if gets.chomp == 'y'
  'Okay! Rebooting the backup node normally.'
else
  exit
end

refresh_linodes
boot_result = `linode-cli linodes reboot #{@backup_node["id"]}`
puts boot_result
wait_for(BACKUP_NODE_LABEL, 'rebooting')
wait_for(BACKUP_NODE_LABEL, 'running')

puts @backup_node

puts "Installing mariadb"
cmd = "apt-get update"
execute_command_on_backup(cmd)
cmd = "apt-get install mariadb-server -y"
execute_command_on_backup(cmd)

puts "Configuring mariadb for accessing the database"
cmd = "chown -R mysql:mysql /data/mariadb"
execute_command_on_backup(cmd)
mysql_conf = "
[server]
datadir=/data/mariadb
socket=/data/mariadb/mysql.sock

[client]
port=3306
socket=/data/mariadb/mysql.sock
"

`echo \"#{mysql_conf}\" | ssh -o StrictHostKeyChecking=no root@#{@backup_node["ipv4"].first} -T \"cat >> /etc/mysql/my.cnf\"`  

cmd = "service mysqld restart"
execute_command_on_backup(cmd)

puts "Dumping the database to your computer"
cmd = "mysqldump --user=wiki --password=wikiedu dashboard > dashboard.sql"
execute_command_on_backup(cmd)
