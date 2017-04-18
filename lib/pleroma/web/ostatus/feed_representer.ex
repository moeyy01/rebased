defmodule Pleroma.Web.OStatus.FeedRepresenter do
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.UserRepresenter

  def to_simple_form(user, activities, users) do
    most_recent_update = List.first(activities).updated_at
    |> NaiveDateTime.to_iso8601

    h = fn(str) -> [to_charlist(str)] end

    entries = []
    [{
      :feed, [
        xmlns: 'http://www.w3.org/2005/Atom',
        "xmlns:activity": 'http://activitystrea.ms/spec/1.0/'
      ], [
        {:id, h.(OStatus.feed_path(user))},
        {:title, ['#{user.nickname}\'s timeline']},
        {:updated, h.(most_recent_update)},
        {:entries, []},
        {:link, [rel: 'hub', href: h.(OStatus.pubsub_path)], []},
        {:author, UserRepresenter.to_simple_form(user)}
      ]
    }]
  end
end
