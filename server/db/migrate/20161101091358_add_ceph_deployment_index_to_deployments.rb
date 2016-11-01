class AddCephDeploymentIndexToDeployments < ActiveRecord::Migration
  def up
    change_table :fusor_deployments do |t|
      t.references :ceph_deployment
      t.index :ceph_deployment_id
    end
  end
end
