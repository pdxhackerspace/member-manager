# frozen_string_literal: true

require 'test_helper'
require 'socket'

module Ollama
  class ChatCompletionTest < ActiveSupport::TestCase
    test 'posts an OpenAI-compatible chat completion request' do
      captured = nil
      response_body = {
        choices: [
          { message: { content: '{"ok":true}' } }
        ]
      }

      with_json_server(response_body) do |base_url, requests|
        result = ChatCompletion.call(
          base_url: base_url,
          model: 'test-model',
          system: 'Be helpful.',
          user: 'Rewrite this.',
          options: { api_key: 'secret-token', format_json: true }
        )

        captured = requests.first
        assert result.ok, result.error
        assert_equal '{"ok":true}', result.assistant_content
      end

      assert_equal '/v1/chat/completions', captured[:path]
      assert_equal 'Bearer secret-token', captured[:authorization]

      body = JSON.parse(captured[:body])
      assert_equal 'test-model', body['model']
      assert_equal false, body['stream']
      assert_equal({ 'type' => 'json_object' }, body['response_format'])
      assert_equal(
        [
          { 'role' => 'system', 'content' => 'Be helpful.' },
          { 'role' => 'user', 'content' => 'Rewrite this.' }
        ],
        body['messages']
      )
    end

    test 'reports empty OpenAI-compatible assistant message' do
      response_body = { choices: [{ message: { content: '' } }] }

      with_json_server(response_body) do |base_url, _requests|
        result = ChatCompletion.call(base_url: base_url, model: 'test-model', system: '', user: '')
        assert_not result.ok
        assert_equal 'Empty assistant message', result.error
      end
    end

    private

    def with_json_server(response_body)
      requests = []
      body = JSON.generate(response_body)
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      thread = Thread.new do
        socket = server.accept
        raw_request = read_http_request(socket)
        requests << parse_http_request(raw_request)
        socket.write(http_response(body))
        socket.close
      end
      yield "http://127.0.0.1:#{port}", requests
    ensure
      server&.close
      thread&.join
    end

    def read_http_request(socket)
      request = +''
      request << socket.readpartial(1024) until request.include?("\r\n\r\n")

      headers, body = request.split("\r\n\r\n", 2)
      length = headers[/\r\nContent-Length:\s*(\d+)/i, 1].to_i
      body ||= ''
      body << socket.read(length - body.bytesize) if body.bytesize < length

      "#{headers}\r\n\r\n#{body}"
    end

    def parse_http_request(raw_request)
      headers, body = raw_request.split("\r\n\r\n", 2)
      request_line, *header_lines = headers.lines.map(&:chomp)
      header_values = header_lines.each_with_object({}) do |line, values|
        key, value = line.split(':', 2)
        values[key.downcase] = value.to_s.strip
      end

      {
        path: request_line.split[1],
        body: body,
        authorization: header_values['authorization']
      }
    end

    def http_response(body)
      [
        'HTTP/1.1 200 OK',
        'Content-Type: application/json',
        "Content-Length: #{body.bytesize}",
        'Connection: close',
        '',
        body
      ].join("\r\n")
    end
  end
end
