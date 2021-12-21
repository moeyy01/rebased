defmodule Pleroma.Repo.Migrations.AddActivityFieldsToObjects do
  use Ecto.Migration

  @function_name "update_status_visibility_counter_cache"
  @trigger_name "status_visibility_counter_cache_trigger"

  def up do
    alter table(:objects) do
      add(:local, :boolean)
      add(:actor, :string)
      add(:recipients, {:array, :string})
    end

    create_if_not_exists(index(:objects, [:local]))
    create_if_not_exists(index(:objects, [:actor, "id DESC NULLS LAST"]))
    create_if_not_exists(index(:objects, [:recipients], using: :gin))

    create_if_not_exists(
      index(:objects, ["(data->'to')"], name: :activities_to_index, using: :gin)
    )

    create_if_not_exists(
      index(:objects, ["(data->'cc')"], name: :activities_cc_index, using: :gin)
    )

    # Copy all activities into the newly formatted objects table
    execute("INSERT INTO objects (SELECT * FROM activities)")

    # Update notifications foreign key
    execute("alter table notifications drop constraint notifications_activity_id_fkey")

    execute(
      "alter table notifications add constraint notifications_object_id_fkey foreign key (activity_id) references objects(id) on delete cascade"
    )

    # Update bookmarks foreign key
    execute("alter table bookmarks drop constraint bookmarks_activity_id_fkey")

    execute(
      "alter table bookmarks add constraint bookmarks_object_id_fkey foreign key (activity_id) references objects(id) on delete cascade"
    )

    # Update report notes foreign key
    execute("alter table report_notes drop constraint report_notes_activity_id_fkey")

    execute(
      "alter table report_notes add constraint report_notes_object_id_fkey foreign key (activity_id) references objects(id)"
    )

    # Nuke the old activities table
    execute("drop table activities")

    # Update triggers
    """
    CREATE TRIGGER #{@trigger_name}
    BEFORE
      INSERT
      OR UPDATE of recipients, data
      OR DELETE
    ON objects
    FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}();
    """
    |> execute()

    execute("drop function if exists thread_visibility(actor varchar, activity_id varchar)")
    execute(update_thread_visibility())
  end

  def down do
    raise "Lol, there's no going back from this."
  end

  # It acts upon objects instead of activities now
  def update_thread_visibility do
    """
    CREATE OR REPLACE FUNCTION thread_visibility(actor varchar, object_id varchar) RETURNS boolean AS $$
    DECLARE
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
      child objects%ROWTYPE;
      object objects%ROWTYPE;
      author_fa varchar;
      valid_recipients varchar[];
      actor_user_following varchar[];
    BEGIN
      --- Fetch actor following
      SELECT array_agg(following.follower_address) INTO actor_user_following FROM following_relationships
      JOIN users ON users.id = following_relationships.follower_id
      JOIN users AS following ON following.id = following_relationships.following_id
      WHERE users.ap_id = actor;

      --- Fetch our initial object.
      SELECT * INTO object FROM objects WHERE objects.data->>'id' = object_id;

      LOOP
        --- Ensure that we have an object before continuing.
        --- If we don't, the thread is not satisfiable.
        IF object IS NULL THEN
          RETURN false;
        END IF;

        --- We only care about Create objects.
        IF object.data->>'type' != 'Create' THEN
          RETURN true;
        END IF;

        --- Normalize the child object into child.
        SELECT * INTO child FROM objects
        WHERE COALESCE(object.data->'object'->>'id', object.data->>'object') = objects.data->>'id';

        --- Fetch the author's AS2 following collection.
        SELECT COALESCE(users.follower_address, '') INTO author_fa FROM users WHERE users.ap_id = object.actor;

        --- Prepare valid recipients array.
        valid_recipients := ARRAY[actor, public];
        IF ARRAY[author_fa] && actor_user_following THEN
          valid_recipients := valid_recipients || author_fa;
        END IF;

        --- Check visibility.
        IF NOT valid_recipients && object.recipients THEN
          --- object not visible, break out of the loop
          RETURN false;
        END IF;

        --- If there's a parent, load it and do this all over again.
        IF (child.data->'inReplyTo' IS NOT NULL) AND (child.data->'inReplyTo' != 'null'::jsonb) THEN
          SELECT * INTO object FROM objects
          WHERE child.data->>'inReplyTo' = objects.data->>'id';
        ELSE
          RETURN true;
        END IF;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """
  end
end
