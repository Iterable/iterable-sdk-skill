#!/usr/bin/env ruby

project_path = ARGV.fetch(0) do
  abort "usage: normalize-xcodegen-push-capability.rb <project.pbxproj>"
end

contents = File.read(project_path)
serialized_shapes = [
  'SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": 1]]";',
  'SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": true]]";'
].freeze
serialized_assignment_pattern =
  /SystemCapabilities\s*=\s*"(?:\\.|[^"\\])*";/
replacement = <<~PBX.chomp
  SystemCapabilities = {
    com.apple.Push = {
      enabled = 1;
    };
  };
PBX

def system_capability_blocks(contents)
  blocks = []
  current = nil
  depth = 0

  contents.each_line do |line|
    if current.nil?
      next unless line.match?(/^\s*SystemCapabilities = \{\s*$/)

      current = +""
      depth = 0
    end

    current << line
    depth += line.count("{")
    depth -= line.count("}")
    if depth.zero?
      blocks << current
      current = nil
    end
  end

  blocks << current unless current.nil?
  blocks
end

def valid_push_dictionary?(block)
  block.match?(
    /com\.apple\.Push = \{\s*enabled = 1;\s*\};/m
  )
end

serialized_assignments = contents.scan(serialized_assignment_pattern)
supported_serialized_assignments =
  serialized_assignments.select { |assignment| serialized_shapes.include?(assignment) }
unsupported_serialized_assignments =
  serialized_assignments - supported_serialized_assignments

unless unsupported_serialized_assignments.empty?
  shapes = unsupported_serialized_assignments.uniq.map(&:inspect).join(", ")
  abort(
    "error: unsupported serialized SystemCapabilities shape: #{shapes}; " \
    "expected exactly one serialized com.apple.Push capability with " \
    "enabled set to 1 or true"
  )
end

serialized_count = supported_serialized_assignments.length
blocks = system_capability_blocks(contents)
dictionary_count = blocks.count { |block| valid_push_dictionary?(block) }

case [serialized_count, blocks.length, dictionary_count]
when [1, 0, 0]
  contents = contents.sub(supported_serialized_assignments.fetch(0), replacement)
  File.write(project_path, contents)
when [0, 1, 1]
  # Already correct. Leave the generated project byte-for-byte unchanged.
else
  abort(
    "error: expected exactly one known Push capability shape; " \
    "found serialized=#{serialized_count}, " \
    "SystemCapabilities blocks=#{blocks.length}, " \
    "valid Push dictionaries=#{dictionary_count}"
  )
end

verified = File.read(project_path)
verified_serialized_count =
  verified.scan(serialized_assignment_pattern).count do |assignment|
    serialized_shapes.include?(assignment)
  end
verified_blocks = system_capability_blocks(verified)
verified_dictionary_count =
  verified_blocks.count { |block| valid_push_dictionary?(block) }
unless verified_serialized_count.zero? &&
       verified_blocks.length == 1 &&
       verified_dictionary_count == 1
  abort(
    "error: Push capability verification failed; " \
    "found serialized=#{verified_serialized_count}, " \
    "SystemCapabilities blocks=#{verified_blocks.length}, " \
    "valid Push dictionaries=#{verified_dictionary_count}"
  )
end
