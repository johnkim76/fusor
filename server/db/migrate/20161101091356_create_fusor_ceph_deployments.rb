class CreateFusorCephDeployments < ActiveRecord::Migration
  def up
    create_table :fusor_ceph_deployments do |t|
      t.string :ssh_user,                    :default => "root"
      t.string :ssh_pass
      t.boolean :poc,                        :default => "false"
      t.boolean :configure_firewall,         :default => "true"
      t.boolean :configure_ntp,              :default => "true"
      t.boolean :configure_rhsm,              :default => "true"
      t.string :mons, :array => true,        :default => []
      t.string :osds, :array => true,        :default => []
      t.string :monitor_interface,           :default => "eth0"
      t.integer :journal_size,               :default => 10_000
      t.string :public_network
      t.boolean :calamari,                   :default => true
      t.boolean :journal_collocation,        :default => true
      t.string :osd_devicess, :array => true
      t.string :journal_device
      t.boolean :crush_location,             :default => false
      t.string :osd_crush_location
      t.timestamps
    end
  end
end
