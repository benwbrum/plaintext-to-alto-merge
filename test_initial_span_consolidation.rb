#!/usr/bin/env ruby

# Test script to verify the initial span consolidation fix for issue #9
# Tests the specific case where multiple words at the beginning of plaintext 
# should be aligned into a single word at the beginning of ALTO

def test_initial_span_consolidation(corrected_file, alto_file, test_name)
  puts "Testing initial span consolidation for #{test_name}"
  
  # Capture output with verbose flag to see alignment details
  output = `ruby merge.rb --verbose #{corrected_file} #{alto_file} 2>&1`
  
  # Find the final alignment output (after Phase F)
  final_output_match = output.match(/Phase F: Remove unaligned XML elementsCurrent ALTO XML text alignment:\n(.*)$/m)
  
  if final_output_match
    final_output = final_output_match[1]
    
    # Check that the first words are properly aligned and not showing as underscores
    # For the 34232508 case, we expect "To" (first plaintext word) to be consolidated 
    # into "Mr" (first ALTO word), so there should be no leading "___"
    lines = final_output.split("\n").reject(&:empty?)
    
    if lines.length > 0
      first_line = lines[0].strip
      puts "  First line of final output: '#{first_line}'"
      
      # The first line should not start with "___" if initial consolidation worked
      if first_line.start_with?("___")
        puts "✗ FAILURE: Initial words not properly consolidated (still showing underscores)"
        puts "  Expected: First plaintext words consolidated into first ALTO word"
        puts "  Actual: First line starts with '___'"
        return false
      else
        puts "✓ SUCCESS: Initial words properly consolidated (no leading underscores)"
        return true
      end
    else
      puts "✗ ERROR: No final output lines found"
      return false
    end
  else
    puts "✗ ERROR: Could not find final output section"
    return false
  end
end

# Test the specific case mentioned in issue #9
puts "=== Testing Initial Span Consolidation Fix (Issue #9) ===\n"

results = []
results << test_initial_span_consolidation("tests/alto_samples/34232508_plaintext.txt", "tests/alto_samples/34232508_alto.xml", "34232508 (To Mr -> Mr)")

puts "\n=== Test Results ==="
success_count = results.count(true)
total_count = results.size

puts "#{success_count}/#{total_count} tests passed"

if success_count == total_count
  puts "✓ All initial span consolidation tests passed! Issue #9 is fixed."
  exit 0
else
  puts "✗ Some initial span consolidation tests failed."
  exit 1
end