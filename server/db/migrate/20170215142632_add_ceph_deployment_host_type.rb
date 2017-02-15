class AddCephDeploymentHostType < ActiveRecord::Migration
  def change
    create_table :fusor_ceph_deployment_hosts do |t|
      t.integer :ceph_deployment_id, :null => false
      t.integer :discovered_host_id, :null => false
      t.string :deployment_host_type, :null => false, :default => "osd"

      t.timestamps
    end
  end
end
