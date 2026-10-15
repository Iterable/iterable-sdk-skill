#!/usr/bin/env ruby

project_path = ARGV.fetch(0) do
  abort "usage: normalize-xcodegen-push-capability.rb <project.pbxproj>"
end

contents = File.read(project_path)
serialized = 'SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": 1]]";'
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

serialized_count = contents.scan(serialized).length
blocks = system_capability_blocks(contents)
dictionary_count = blocks.count { |block| valid_push_dictionary?(block) }

case [serialized_count, blocks.length, dictionary_count]
when [1, 0, 0]
  contents = contents.sub(serialized, replacement)
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
verified_serialized_count = verified.scan(serialized).length
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
