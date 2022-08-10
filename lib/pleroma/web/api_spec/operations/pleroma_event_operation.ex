# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaEventOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.ParticipationRequest
  alias Pleroma.Web.ApiSpec.Schemas.Status

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Publish new status",
      security: [%{"oAuth" => ["write"]}],
      description: "Create a new event",
      operationId: "PleromaAPI.EventController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => event_response(),
        422 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def participations_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participants list",
      description: "View who joined a given event",
      operationId: "EventController.participations",
      security: [%{"oAuth" => ["read"]}],
      parameters: [id_param()],
      responses: %{
        200 =>
          Operation.response(
            "Array of Accounts",
            "application/json",
            AccountOperation.array_of_accounts()
          ),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def participation_requests_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participation requests list",
      description: "View who wants to join the event",
      operationId: "EventController.participations",
      security: [%{"oAuth" => ["read"]}],
      parameters: [id_param()],
      responses: %{
        200 =>
          Operation.response(
            "Array of participation requests",
            "application/json",
            array_of_participation_requests()
          ),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def participate_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participate",
      security: [%{"oAuth" => ["write"]}],
      description: "Participate in an event",
      operationId: "PleromaAPI.EventController.participate",
      parameters: [id_param()],
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              participation_message: %Schema{
                type: :string,
                description: "Why the user wants to participate"
              }
            }
          },
          required: false
        ),
      responses: %{
        200 => event_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def unparticipate_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Unparticipate",
      security: [%{"oAuth" => ["write"]}],
      description: "Delete event participation",
      operationId: "PleromaAPI.EventController.unparticipate",
      parameters: [id_param()],
      responses: %{
        200 => event_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def accept_participation_request_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Accept participation",
      security: [%{"oAuth" => ["write"]}],
      description: "Accept event participation request",
      operationId: "PleromaAPI.EventController.accept_participation_request",
      parameters: [id_param(), participant_id_param()],
      responses: %{
        200 => event_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def reject_participation_request_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Reject participation",
      security: [%{"oAuth" => ["write"]}],
      description: "Reject event participation request",
      operationId: "PleromaAPI.EventController.reject_participation_request",
      parameters: [id_param(), participant_id_param()],
      responses: %{
        200 => event_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "EventCreateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Name of the event."
        },
        status: %Schema{
          type: :string,
          description: "Text description of the event."
        },
        banner_id: %Schema{
          nullable: true,
          type: :string,
          description: "Attachment id to be attached as banner."
        },
        start_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "Start time."
        },
        end_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "End time."
        },
        join_mode: %Schema{
          type: :string,
          enum: ["free", "restricted"]
        }
      },
      example: %{
        "name" => "Example event",
        "status" => "No information for now.",
        "start_time" => "21-02-2022T22:00:00Z",
        "end_time" => "21-02-2022T23:00:00Z"
      }
    }
  end

  defp event_response do
    Operation.response(
      "Status",
      "application/json",
      Status
    )
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Event ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp participant_id_param do
    Operation.parameter(:participant_id, :path, FlakeID, "Event participant ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  def array_of_participation_requests do
    %Schema{
      title: "ArrayOfParticipationRequests",
      type: :array,
      items: ParticipationRequest,
      example: [ParticipationRequest.schema().example]
    }
  end
end
