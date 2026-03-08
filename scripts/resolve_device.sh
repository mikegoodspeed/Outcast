#!/bin/zsh
set -euo pipefail

if [[ -n "${DEVICE_ID:-}" ]]; then
  print -r -- "$DEVICE_ID"
  exit 0
fi

JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/outcast-devices.XXXXXX.json")"

cleanup() {
  rm -f "$JSON_FILE"
}

trap cleanup EXIT

if ! xcrun devicectl list devices --json-output "$JSON_FILE" >/dev/null; then
  echo "Unable to list connected devices. Ensure an iPhone is connected, trusted, unlocked, and that Developer Mode is enabled." >&2
  exit 1
fi

RESOLVED_DEVICE_ID="$(
  /usr/bin/ruby -rjson -e '
    id_keys = %w[identifier udid targetIdentifier deviceIdentifier]

    def flatten_values(value, values)
      case value
      when Hash
        value.each do |key, nested|
          values << key.to_s
          flatten_values(nested, values)
        end
      when Array
        value.each { |item| flatten_values(item, values) }
      when NilClass
      else
        values << value.to_s
      end
      values
    end

    def collect_candidates(value, id_keys, candidates)
      case value
      when Hash
        keys = value.keys.map(&:to_s)
        candidates << value if (keys & id_keys).any?
        value.each_value { |nested| collect_candidates(nested, id_keys, candidates) }
      when Array
        value.each { |item| collect_candidates(item, id_keys, candidates) }
      end
      candidates
    end

    payload = JSON.parse(File.read(ARGV.fetch(0)))
    candidates = collect_candidates(payload, id_keys, []).uniq

    selected = candidates.find do |candidate|
      text = flatten_values(candidate, []).join(" ").downcase
      next false unless text.include?("iphone")
      next false if text.include?("simulator") || text.include?("placeholder") || text.include?("my mac")
      next false if text.match?(/\bdisconnected\b|\boffline\b|\bunavailable\b|\bunsupported\b/)
      true
    end

    if selected
      device_id = id_keys.lazy.map { |key| selected[key] || selected[key.to_sym] }.find { |value| !value.nil? && !value.to_s.empty? }
      puts device_id if device_id
    end
  ' "$JSON_FILE"
)"

if [[ -z "$RESOLVED_DEVICE_ID" ]]; then
  echo "No connected available iPhone found. Connect and unlock an iPhone, trust this Mac, and enable Developer Mode." >&2
  exit 1
fi

print -r -- "$RESOLVED_DEVICE_ID"
