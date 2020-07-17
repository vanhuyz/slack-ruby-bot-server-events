# frozen_string_literal: true

require 'spec_helper'

describe SlackRubyBotServer::Slack::Api::Endpoints::Slack::ActionsEndpoint do
  include SlackRubyBotServer::Slack::Api::Test::EndpointTest

  it 'checks signature' do
    post '/api/slack/action'
    expect(last_response.status).to eq 403
    response = JSON.parse(last_response.body)
    expect(response).to eq('error' => 'Invalid Signature')
  end

  context 'without signature checks' do
    before do
      allow_any_instance_of(Slack::Events::Request).to receive(:verify!)
    end

    context 'with an action handler' do
      before do
        SlackRubyBotServer::Slack.configure do |config|
          config.on :action do |action|
            if action[:payload][:callback_id] == 'action_id'
              { text: 'Success!' }
            else
              raise "Action #{action[:payload][:callback_id]} is not supported."
            end
          end
        end
      end

      let(:payload) do
        {
          actions: [{ name: 'id', value: '43749' }],
          channel: { id: 'C12345', name: 'channel' },
          user: { id: 'user_id' },
          team: { id: 'team_id' },
          token: 'deprecated',
          callback_id: 'action_id'
        }
      end

      it 'performs action' do
        post '/api/slack/action', payload: payload.merge(callback_id: 'action_id').to_json
        expect(last_response.status).to eq 201
        response = JSON.parse(last_response.body)
        expect(response).to eq('text' => 'Success!')
      end

      it 'errors on an unhandled action' do
        post '/api/slack/action', payload: payload.merge(callback_id: 'invalid').to_json
        expect(last_response.status).to eq 400
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq('Action invalid is not supported.')
      end
    end
  end
end
