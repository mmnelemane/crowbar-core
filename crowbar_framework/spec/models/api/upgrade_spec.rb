require "spec_helper"

describe Api::Upgrade do
  let!(:upgrade_prechecks) do
    JSON.parse(
      File.read(
        "spec/fixtures/upgrade_prechecks.json"
      )
    )
  end
  let!(:upgrade_status) do
    JSON.parse(
      File.read(
        "spec/fixtures/upgrade_status.json"
      )
    )
  end
  let!(:node_repocheck) do
    JSON.parse(
      File.read(
        "spec/fixtures/node_repocheck.json"
      )
    )
  end
  let!(:crowbar_repocheck) do
    JSON.parse(
      File.read(
        "spec/fixtures/crowbar_repocheck.json"
      )
    )
  end
  let!(:crowbar_repocheck_zypper) do
    File.read(
      "spec/fixtures/crowbar_repocheck_zypper.xml"
    ).to_s
  end
  let!(:crowbar_repocheck_zypper_locked) do
    File.read(
      "spec/fixtures/crowbar_repocheck_zypper_locked.xml"
    ).to_s
  end

  before(:each) do
    allow(Api::Node).to(
      receive(:node_architectures).and_return(
        "os" => ["x86_64"],
        "openstack" => ["x86_64"],
        "ceph" => ["x86_64"],
        "ha" => ["x86_64"]
      )
    )
    allow(NodeObject).to(
      receive(:all).and_return([NodeObject.find_node_by_name("testing")])
    )
    allow(Api::Upgrade).to(
      receive(:target_platform).and_return("suse-12.2")
    )
    allow(::Crowbar::Repository).to(
      receive(:provided_and_enabled?).and_return(true)
    )
    ["os", "ceph", "ha", "openstack"].each do |feature|
      allow(::Crowbar::Repository).to(
        receive(:provided_and_enabled_with_repolist).with(
          feature, "suse-12.2", "x86_64"
        ).and_return([true, {}])
      )
    end
  end

  context "with a successful status" do
    it "checks the status" do
      allow(Api::Upgrade).to receive(:network_checks).and_return([])
      allow(Api::Upgrade).to receive(
        :maintenance_updates_status
      ).and_return({})
      allow(Api::Crowbar).to receive(
        :addons
      ).and_return(["ceph", "ha"])

      expect(subject.class).to respond_to(:status)
      expect(subject.class.status).to be_a(Hash)
      expect(subject.class.status.deep_stringify_keys).to eq(upgrade_status)
    end
  end

  context "with a successful maintenance updates check" do
    it "checks the maintenance updates on crowbar" do
      allow(Api::Upgrade).to receive(:network_checks).and_return([])
      allow(Api::Upgrade).to receive(
        :maintenance_updates_status
      ).and_return({})
      allow(Api::Crowbar).to receive(
        :addons
      ).and_return(["ceph", "ha"])

      expect(subject.class).to respond_to(:checks)
      expect(subject.class.checks.deep_stringify_keys).to eq(upgrade_prechecks)
    end
  end

  context "with a successful services shutdown" do
    it "prepares and shuts down services on cluster founder nodes" do
      allow_any_instance_of(CrowbarService).to receive(
        :prepare_nodes_for_os_upgrade
      ).and_return(true)
      allow(NodeObject).to(
        receive(:find).with("state:crowbar_upgrade AND pacemaker_founder:true").
        and_return([NodeObject.find_node_by_name("testing.crowbar.com")])
      )
      allow(NodeObject).to(
        receive(:find).with("state:crowbar_upgrade AND NOT run_list_map:pacemaker-cluster-member").
        and_return([])
      )
      allow_any_instance_of(NodeObject).to receive(:ssh_cmd).with(
        "/usr/sbin/crowbar-shutdown-services-before-upgrade.sh"
      ).and_return(true)

      expect(subject.class.services).to eq(
        status: :ok,
        message: ""
      )
    end

    it "prepares and shuts down services on non clustered nodes" do
      allow_any_instance_of(CrowbarService).to receive(
        :prepare_nodes_for_os_upgrade
      ).and_return(true)
      allow(NodeObject).to(
        receive(:find).with("state:crowbar_upgrade AND pacemaker_founder:true").
        and_return([])
      )
      allow(NodeObject).to(
        receive(:find).with("state:crowbar_upgrade AND NOT run_list_map:pacemaker-cluster-member").
        and_return([NodeObject.find_node_by_name("testing.crowbar.com")])
      )
      allow_any_instance_of(NodeObject).to receive(:ssh_cmd).with(
        "/usr/sbin/crowbar-shutdown-services-before-upgrade.sh"
      ).and_return(true)

      expect(subject.class.services).to eq(
        status: :ok,
        message: ""
      )
    end
  end

  context "with a failure during services shutdown" do
    it "fails when chef client does not preapre the scripts" do
      allow_any_instance_of(CrowbarService).to receive(
        :prepare_nodes_for_os_upgrade
      ).and_raise("some Error")

      expect(subject.class.services).to eq(
        status: :unprocessable_entity,
        message: "some Error"
      )
    end
  end

  context "with a successful node repocheck" do
    it "checks the repositories for the nodes" do
      os_repo_fixture = node_repocheck.tap do |k|
        k.delete("ceph")
        k.delete("ha")
      end

      expect(subject.class.noderepocheck).to eq(os_repo_fixture)
    end
  end

  context "with addon installed but not deployed" do
    it "shows that there are no addons deployed" do
      allow_any_instance_of(Api::Crowbar).to(
        receive(:features).and_return(
          ["ceph", "ha"]
        )
      )
      allow(Api::Node).to(
        receive(:ceph_node?).with(anything).and_return(false)
      )
      allow(Api::Node).to(
        receive(:pacemaker_node?).with(anything).and_return(false)
      )
      allow(Api::Node).to(
        receive(:node_architectures).and_return(
          "os" => ["x86_64"],
          "openstack" => ["x86_64"]
        )
      )

      expected = node_repocheck.tap do |k|
        k.delete("ceph")
        k.delete("ha")
      end

      expect(subject.class.noderepocheck).to eq(expected)
    end
  end

  context "with repositories not in place" do
    it "lists the repositories that are not available" do
      allow(Api::Upgrade).to(
        receive(:repo_version_available?).and_return(false)
      )
      allow(Api::Upgrade).to(
        receive(:admin_architecture).and_return("x86_64")
      )
      allow_any_instance_of(Kernel).to(
        receive(:`).with(
          "sudo /usr/bin/zypper-retry --xmlout products"
        ).and_return(crowbar_repocheck_zypper)
      )

      expect(subject.class.adminrepocheck.deep_stringify_keys).to_not(
        eq(crowbar_repocheck)
      )
    end
  end

  context "with a locked zypper" do
    it "shows an error message that zypper is locked" do
      allow(Api::Crowbar).to(
        receive(:repo_version_available?).and_return(false)
      )
      allow_any_instance_of(Kernel).to(
        receive(:`).with(
          "sudo /usr/bin/zypper-retry --xmlout products"
        ).and_return(crowbar_repocheck_zypper_locked)
      )

      check = subject.class.adminrepocheck
      expect(check[:status]).to eq(:service_unavailable)
      expect(check[:message]).to eq(
        Hash.from_xml(crowbar_repocheck_zypper_locked)["stream"]["message"]
      )
    end
  end

  context "with repositories in place" do
    it "lists the available repositories" do
      allow(Api::Upgrade).to(
        receive(:repo_version_available?).and_return(true)
      )
      allow_any_instance_of(Kernel).to(
        receive(:`).with(
          "sudo /usr/bin/zypper-retry --xmlout products"
        ).and_return(crowbar_repocheck_zypper)
      )

      expect(subject.class.adminrepocheck.deep_stringify_keys).to(
        eq(crowbar_repocheck)
      )
    end
  end

  context "upgrading the nodes" do
    it "successfully upgrades the nodes" do
      allow(NodeObject).to(
        receive(:find).
        with("state:crowbar_upgrade AND (roles:database-server OR roles:rabbitmq-server)").
        and_return([NodeObject.find_node_by_name("testing.crowbar.com")])
      )
      allow_any_instance_of(NodeObject).to receive(:run_ssh_cmd).and_return(
        stdout: "",
        stderr: "",
        exit_code: 1
      )
      allow_any_instance_of(Api::Node).to receive(:upgrade).and_return(true)

      expect(subject.class.nodes).to be true
    end

    it "fails during the upgrade of controller nodes" do
      allow(subject.class).to(
        receive(:upgrade_controller_nodes).and_return(false)
      )

      expect(subject.class.nodes).to be false
    end
  end

  context "canceling the upgrade" do
    it "successfully cancels the upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :revert_nodes_from_crowbar_upgrade
      ).and_return(true)

      expect(subject.class.cancel).to eq(
        status: :ok,
        message: ""
      )
    end

    it "fails to cancel the upgrade" do
      allow_any_instance_of(CrowbarService).to receive(
        :revert_nodes_from_crowbar_upgrade
      ).and_raise("Some Error")

      expect(subject.class.cancel).to eq(
        status: :unprocessable_entity,
        message: "Some Error"
      )
    end
  end
end
