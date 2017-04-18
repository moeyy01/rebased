defmodule Pleroma.Web.OStatus.FeedRepresenterTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.User
  alias Pleroma.Web.OStatus.{FeedRepresenter, UserRepresenter}
  alias Pleroma.Web.OStatus

  test "returns a feed of the last 20 items of the user" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    tuple = FeedRepresenter.to_simple_form(user, [note_activity], [user])

    most_recent_update = note_activity.updated_at
    |> NaiveDateTime.to_iso8601

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary
    user_xml = UserRepresenter.to_simple_form(user)
    |> :xmerl.export_simple_content(:xmerl_xml)

    expected = """
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:activity="http://activitystrea.ms/spec/1.0/">
      <id>#{OStatus.feed_path(user)}</id>
      <title>#{user.nickname}'s timeline</title>
      <updated>#{most_recent_update}</updated>
      <entries />
      <link rel="hub" href="#{OStatus.pubsub_path}" />
      <author>
        #{user_xml}
      </author>
    </feed>
    """
    assert clean(res) == clean(expected)
  end

  defp clean(string) do
    String.replace(string, ~r/\s/, "")
  end
end
