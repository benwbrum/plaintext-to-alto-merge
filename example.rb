#!/usr/bin/env ruby

# Example usage of the plaintext-to-alto-merge Ruby gem

require_relative 'lib/plaintext_to_alto_merge'

puts "=== plaintext-to-alto-merge Ruby Gem Example ==="

# Example 1: Simple API usage
puts "\n1. Simple API Usage:"
corrected_text = File.read('samples/1151285_corrected.txt')
alto_xml = File.read('samples/1151285_alto.xml')

result = PlaintextToAltoMerge.merge(
  corrected_text: corrected_text,
  alto_xml: alto_xml,
  verbose: false
)

puts "   ✓ Processed #{corrected_text.split.size} words"
puts "   ✓ Generated #{result.length} characters of corrected ALTO XML"

# Example 2: Class-based approach with statistics
puts "\n2. Class-based Approach:"
merger = PlaintextToAltoMerge::Merger.new(verbose: false)
result = merger.merge(corrected_text: corrected_text, alto_xml: alto_xml)

puts "   ✓ Alignment percentage: #{merger.final_alignment_percentage.round(2)}%"
puts "   ✓ Output contains Processing element: #{result.include?('Processing')}"

# Example 3: File processing
puts "\n3. File Processing:"
result = merger.merge_files(
  corrected_file: 'samples/1151285_corrected.txt',
  alto_file: 'samples/1151285_alto.xml'
)

puts "   ✓ File processing successful"

# Example 4: Error handling
puts "\n4. Error Handling:"
begin
  PlaintextToAltoMerge.merge(
    corrected_text: "test",
    alto_xml: "<not-alto>invalid</not-alto>"
  )
rescue PlaintextToAltoMerge::Error => e
  puts "   ✓ Caught expected error: #{e.message[0..50]}..."
end

puts "\n=== Example Complete ==="
puts "The gem is ready for use in your Ruby applications!"