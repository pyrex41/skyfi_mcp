# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     SkyfiMcp.Repo.insert!(%SkyfiMcp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias SkyfiMcp.{Repo, AccessKey}

# Create default access key for MCP client if it doesn't exist
access_key = "sk_mcp_9a7312e31449dea2cd075997284c6f6b6261c0abebad48adc62a66bcd3e48aba"

unless Repo.get_by(AccessKey, key: access_key) do
  %AccessKey{}
  |> AccessKey.changeset(%{
    key: access_key,
    user_email: "mcp-client@example.com",
    description: "Default MCP Client Access Key",
    active: true
  })
  |> Repo.insert!()

  IO.puts("✓ Created default MCP access key")
else
  IO.puts("✓ MCP access key already exists")
end
