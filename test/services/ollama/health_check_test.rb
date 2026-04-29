# frozen_string_literal: true

require 'test_helper'
require 'socket'

module Ollama
  class HealthCheckTest < ActiveSupport::TestCase
    test 'checks OpenAI-compatible models endpoint' do
      captured = nil

      with_json_server({ data: [] }) do |base_url, requests|
        result = HealthCheck.call(base_url: base_url, api_key: 'secret-token')
        captured = requests.first
        assert result.ok, result.error
      end

      assert_equal '/v1/models', captured[:path]
      assert_equal 'Bearer secret-token', captured[:authorization]
    end

    test 'fails when models endpoint returns invalid JSON' do
      with_raw_server('not json') do |base_url|
        result = HealthCheck.call(base_url: base_url)
        assert_not result.ok
        assert_match(/Invalid response/, result.error)
      end
    end

    private

    def with_json_server(response_body)
      requests = []
      with_server(JSON.generate(response_body), requests: requests) do |base_url|
        yield base_url, requests
      end
    end

    def with_raw_server(response_body, &block)
      with_server(response_body, requests: []) do |base_url|
        block.call(base_url)
      end
    end

    def with_server(response_body, requests:)
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      thread = Thread.new do
        socket = server.accept
        raw_request = read_http_request(socket)
        requests << parse_http_request(raw_request)
        socket.write(http_response(response_body))
        socket.close
      end
      yield "http://127.0.0.1:#{port}"
    ensure
      server&.close
      thread&.join
    end

    def read_http_request(socket)
      request = +''
      request << socket.readpartial(1024) until request.include?("\r\n\r\n")
      request
    end

    def parse_http_request(raw_request)
      request_line, *header_lines = raw_request.split("\r\n\r\n", 2).first.lines.map(&:chomp)
      header_values = header_lines.each_with_object({}) do |line, values|
        key, value = line.split(':', 2)
        values[key.downcase] = value.to_s.strip
      end

      {
        path: request_line.split[1],
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
