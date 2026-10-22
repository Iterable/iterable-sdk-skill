#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "openssl"
require "optparse"
require "securerandom"

json_output = STDOUT.dup
$stdout = STDERR

options = {
  confirm: false
}

parser = OptionParser.new do |flags|
  flags.on("--apple-id VALUE") { |value| options[:apple_id] = value }
  flags.on("--team-id VALUE") { |value| options[:team_id] = value }
  flags.on("--name VALUE") { |value| options[:name] = value }
  flags.on("--output-dir VALUE") { |value| options[:output_dir] = value }
  flags.on("--confirm") { options[:confirm] = true }
end

command = ARGV.shift
parser.parse!(ARGV)
abort("unexpected positional arguments") unless ARGV.empty?

unless %w[auth plan create].include?(command)
  abort("usage: ios-apns-private.rb auth|plan|create [options]")
end

apple_id = String(options[:apple_id]).strip
team_id = String(options[:team_id]).strip
name = String(options[:name]).strip

abort("--apple-id is required") if apple_id.empty?
if command != "auth" || !team_id.empty?
  abort("--team-id must be 10 uppercase letters or digits") unless team_id.match?(/\A[A-Z0-9]{10}\z/)
end
if %w[plan create].include?(command)
  abort("--name is required") if name.empty?
  abort("--name contains control characters") if name.match?(/[[:cntrl:]]/)
end

begin
  require "spaceship"
rescue LoadError
  abort("Fastlane Spaceship is not installed in the experimental tool environment")
end

def login(apple_id, team_id)
  Spaceship::Portal.login(apple_id)
  if team_id.empty?
    Spaceship::Portal.select_team
  else
    Spaceship::Portal.client.team_id = team_id
  end
end

def apns_key?(key)
  key.respond_to?(:has_apns?) && key.has_apns?
rescue StandardError
  false
end

def key_summary(key)
  {
    id: String(key.id),
    name: String(key.name),
    can_download: key.respond_to?(:can_download) ? !!key.can_download : nil
  }
end

def validate_apns_private_key!(contents)
  key = OpenSSL::PKey.read(contents)
  abort("Apple download did not contain an EC private key") unless key.is_a?(OpenSSL::PKey::EC)
  abort("Apple download did not contain private key material") unless key.private?
  abort("Apple download used an unexpected EC curve") unless key.group.curve_name == "prime256v1"
end

login(apple_id, team_id)

case command
when "auth"
  json_output.puts(JSON.generate({
    authenticated: true,
    team_id: String(Spaceship::Portal.client.team_id)
  }))
when "plan"
  keys = Spaceship::Portal::Key.all
  apns_keys = keys.select { |key| apns_key?(key) }
  duplicate = keys.any? { |key| String(key.name) == name }
  json_output.puts(JSON.generate({
    tool: "iterable-ios-private-apns",
    contract: 1,
    read_only: true,
    unsupported_private_api: true,
    team_id: team_id,
    requested_name: name,
    existing_apns_keys: apns_keys.map { |key| key_summary(key) },
    blocked_by: duplicate ? ["duplicate_key_name"] : [],
    actions: duplicate ? [] : [{
      action: "create_dedicated_apns_key",
      name: name,
      scope: "team",
      environment: "all",
      download_once: true
    }],
    excludes: [
      "revoking or editing existing keys",
      "retrying an uncertain key creation",
      "printing private key material"
    ]
  }))
when "create"
  abort("create requires --confirm after reviewing the experimental plan") unless options[:confirm]

  output_dir = String(options[:output_dir]).strip
  abort("--output-dir is required") if output_dir.empty?
  output_dir = File.expand_path(output_dir)
  FileUtils.mkdir_p(output_dir, mode: 0o700)
  File.chmod(0o700, output_dir)

  before = Spaceship::Portal::Key.all
  if before.any? { |key| String(key.name) == name }
    abort("a key already has the requested name; inspect it instead of creating a duplicate")
  end

  pending_path = File.join(output_dir, ".pending-iterable-apns-#{SecureRandom.hex(12)}")
  pending = File.open(
    pending_path,
    File::WRONLY | File::CREAT | File::EXCL,
    0o600
  )

  created = nil
  begin
    created = Spaceship::Portal::Key.create(name: name, apns: true)
    contents = created.download
    pending.write(contents)
    pending.flush
    pending.fsync
    pending.close
    validate_apns_private_key!(contents)

    key_id = String(created.id)
    abort("Apple returned an invalid APNs Key ID") unless key_id.match?(/\A[A-Z0-9]{10}\z/)
    final_path = File.join(output_dir, "AuthKey_#{key_id}.p8")
    abort("refusing to replace existing key file #{final_path}") if File.exist?(final_path)

    File.rename(pending_path, final_path)
    File.chmod(0o600, final_path)

    read_back = Spaceship::Portal::Key.all.select { |key| String(key.id) == key_id }
    unless read_back.length == 1 && apns_key?(read_back.first)
      abort("key #{key_id} was downloaded, but Apple read-back did not verify its APNs service; preserve #{final_path} and inspect before retrying")
    end

    json_output.puts(JSON.generate({
      tool: "iterable-ios-private-apns",
      contract: 1,
      unsupported_private_api: true,
      created: true,
      key_id: key_id,
      team_id: team_id,
      key_path: final_path,
      mode: "0600",
      scope: "team",
      environment: "all"
    }))
  rescue Exception
    pending.close unless pending.closed?
    if created.nil? && File.exist?(pending_path) && File.zero?(pending_path)
      File.delete(pending_path)
    end
    raise
  end
end
