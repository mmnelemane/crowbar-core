def upgrade(ta, td, a, d)
  a["dhcp"]["state_machine"]["os_upgrading"] = ta["dhcp"]["state_machine"]["os_upgrading"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["dhcp"]["state_machine"].delete("os_upgrading")
  return a, d
end
