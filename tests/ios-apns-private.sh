#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
PASSED=0

ok() {
  printf 'PASS %s\n' "$1"
  PASSED=$((PASSED + 1))
}

bad() {
  printf 'FAIL %s\n' "$1"
  FAILED=1
}

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-apns-private-test.XXXXXX")"
trap 'find "$fixture_root" -depth -delete' EXIT

fake_lib="$fixture_root/lib"
state="$fixture_root/state"
output_dir="$fixture_root/keys"
mkdir -p "$fake_lib" "$state"

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$state/download.p8" 2>/dev/null

printf '0\n' > "$state/create-count"
printf '0\n' > "$state/download-count"

cat > "$fake_lib/spaceship.rb" <<'RUBY'
module Spaceship
  module Portal
    class Client
      attr_accessor :team_id
    end

    @client = Client.new

    def self.login(apple_id)
      raise "missing apple id" if apple_id.to_s.empty?
    end

    def self.client
      @client
    end

    def self.select_team
      @client.team_id = "TEAMID0001"
    end

    class Key
      attr_reader :id, :name, :can_download

      def initialize(id:, name:, apns:, can_download: true)
        @id = id
        @name = name
        @apns = apns
        @can_download = can_download
      end

      def has_apns?
        @apns
      end

      def self.all
        keys = [
          new(id: "EXISTING01", name: "Existing Provider", apns: true),
          new(id: "OTHERKEY01", name: "Other Service", apns: false)
        ]
        if File.read(File.join(ENV.fetch("APNS_TEST_STATE"), "create-count")).to_i.positive?
          keys << new(id: "APNSKEY001", name: ENV.fetch("APNS_TEST_NAME"), apns: true)
        end
        keys
      end

      def self.create(name:, apns:)
        path = File.join(ENV.fetch("APNS_TEST_STATE"), "create-count")
        count = File.read(path).to_i + 1
        File.write(path, "#{count}\n")
        raise "create called more than once" unless count == 1
        new(id: "APNSKEY001", name: name, apns: apns)
      end

      def download
        path = File.join(ENV.fetch("APNS_TEST_STATE"), "download-count")
        count = File.read(path).to_i + 1
        File.write(path, "#{count}\n")
        raise "download called more than once" unless count == 1
        File.binread(File.join(ENV.fetch("APNS_TEST_STATE"), "download.p8"))
      end
    end
  end
end
RUBY

ruby_bin="/opt/homebrew/opt/ruby/bin/ruby"
[[ -x "$ruby_bin" ]] || ruby_bin="$(command -v ruby)"

if "$ruby_bin" -c tools/ios-apns-private.rb >/dev/null 2>&1; then
  ok "private APNs actor has valid Ruby syntax"
else
  bad "private APNs actor has valid Ruby syntax"
fi

actor() {
  env \
    RUBYLIB="$fake_lib" \
    APNS_TEST_STATE="$state" \
    APNS_TEST_NAME="Iterable Dog Shelter" \
    "$ruby_bin" tools/ios-apns-private.rb "$@"
}

plan="$(actor plan \
  --apple-id developer@example.com \
  --team-id TEAMID0001 \
  --name 'Iterable Dog Shelter')"
if node -e '
  const plan = JSON.parse(process.argv[1]);
  process.exit(
    plan.read_only === true &&
    plan.unsupported_private_api === true &&
    plan.actions.length === 1 &&
    plan.actions[0].action === "create_dedicated_apns_key" &&
    plan.existing_apns_keys.length === 1 &&
    plan.excludes.includes("revoking or editing existing keys")
      ? 0
      : 1
  );
' "$plan" &&
  [[ "$(cat "$state/create-count")" -eq 0 ]]; then
  ok "experimental plan inventories metadata without creating a key"
else
  bad "experimental plan was incomplete or mutated Apple state"
fi

actor create \
  --apple-id developer@example.com \
  --team-id TEAMID0001 \
  --name 'Iterable Dog Shelter' \
  --output-dir "$output_dir" \
  >"$fixture_root/unconfirmed.out" 2>"$fixture_root/unconfirmed.err"
unconfirmed_rc=$?
if [[ "$unconfirmed_rc" -ne 0 && "$(cat "$state/create-count")" -eq 0 ]]; then
  ok "experimental create refuses without confirmation"
else
  bad "experimental create mutated state without confirmation"
fi

created="$(actor create \
  --apple-id developer@example.com \
  --team-id TEAMID0001 \
  --name 'Iterable Dog Shelter' \
  --output-dir "$output_dir" \
  --confirm)"
key_path="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).key_path)' "$created")"
if [[ "$(cat "$state/create-count")" -eq 1 &&
      "$(cat "$state/download-count")" -eq 1 &&
      -f "$key_path" &&
      "$(stat -f '%Lp' "$key_path")" == 600 ]] &&
    openssl pkey -in "$key_path" -noout >/dev/null 2>&1 &&
    ! grep -q 'BEGIN PRIVATE KEY' <<< "$created"; then
  ok "confirmed create performs one creation and one secure download"
else
  bad "confirmed create did not preserve the one-shot key boundary"
fi

actor create \
  --apple-id developer@example.com \
  --team-id TEAMID0001 \
  --name 'Iterable Dog Shelter' \
  --output-dir "$output_dir" \
  --confirm >"$fixture_root/retry.out" 2>"$fixture_root/retry.err"
retry_rc=$?
if [[ "$retry_rc" -ne 0 &&
      "$(cat "$state/create-count")" -eq 1 &&
      "$(cat "$state/download-count")" -eq 1 ]]; then
  ok "duplicate retry is rejected without another remote mutation"
else
  bad "duplicate retry repeated key creation or download"
fi

workspace="$fixture_root/app/.iterable/ios"
mkdir -p "$fixture_root/app"
bin/ios-provision experimental-apns-plan \
  --workspace "$workspace" \
  --apple-id developer@example.com \
  --team-id TEAMID0001 \
  --name 'Iterable Dog Shelter' \
  --confirm-read >"$fixture_root/no-opt-in.out" 2>"$fixture_root/no-opt-in.err"
opt_in_rc=$?
if [[ "$opt_in_rc" -ne 0 && ! -e "$workspace" ]]; then
  ok "private API commands require explicit experimental opt-in"
else
  bad "private API command ran without explicit experimental opt-in"
fi

fake_runtime="$fixture_root/fake-runtime"
mkdir -p "$fake_runtime"
cat > "$fake_runtime/ruby" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == -e && "${2:-}" == *'print RUBY_VERSION'* ]]; then
  printf '3.3.0'
  exit 0
fi
if [[ "${1:-}" == -e && "${2:-}" == *'Gem::Version.new(RUBY_VERSION)'* ]]; then
  exit 0
fi
exit 1
SH
cat > "$fake_runtime/gem" <<'SH'
#!/usr/bin/env bash
exit 9
SH
chmod +x "$fake_runtime/ruby" "$fake_runtime/gem"

failed_install_workspace="$fixture_root/failed-install/.iterable/ios"
IOS_EXPERIMENTAL_RUBY="$fake_runtime/ruby" \
  bin/ios-provision experimental-apns-install \
    --workspace "$failed_install_workspace" \
    --experimental \
    --confirm \
    >"$fixture_root/failed-install.out" 2>"$fixture_root/failed-install.err"
failed_install_rc=$?
if [[ "$failed_install_rc" -ne 0 ]] &&
    ! grep -q '"dependencies_ready":true' "$fixture_root/failed-install.out"; then
  ok "failed dependency installation cannot report a ready state"
else
  bad "failed dependency installation produced a false ready state"
fi

printf '%d checks\n' "$PASSED"
exit "$FAILED"
