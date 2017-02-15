class AddDeployCephToDeployments < ActiveRecord::Migration
  def up
    add_column :fusor_deployments, :deploy_ceph, :boolean, :default => false
  end
end
