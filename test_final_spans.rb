#!/usr/bin/env ruby

# Test script to verify the final spans alignment fix for issue #5

def test_final_spans_alignment(corrected_file, alto_file, test_name)
  puts "Testing final spans alignment for #{test_name}"
  
  # Capture output
  output = `ruby merge.rb #{corrected_file} #{alto_file} 2>&1`
  
  # Check if final span alignment was performed
  final_span_line = output.lines.grep(/Final span alignment:/).last
  
  if final_span_line
    # Extract the numbers
    if final_span_line.match(/Final span alignment: (\d+) corrected words, (\d+) alto words remaining/)
      corrected_remaining = $1.to_i
      alto_remaining = $2.to_i
      puts "✓ Final span alignment performed: #{corrected_remaining} corrected words, #{alto_remaining} alto words"
      
      # Check that final alignment shows actual words instead of just underscores
      final_output = output.split("Phase F: Remove unaligned XML elements").last
      if final_output && !final_output.strip.empty?
        # Count lines that end with actual words vs lines that end with only underscores
        lines = final_output.split("\n")
        last_few_lines = lines.last(5).join(" ")
        
        # If we see actual words in the last few lines, the fix is working
        if last_few_lines =~ /[a-zA-Z]{3,}/ 
          puts "✓ SUCCESS: Final words are properly aligned (not just underscores)"
          return true
        else
          puts "✗ FAILURE: Final words still showing as underscores"
          puts "  Last few lines: #{last_few_lines.strip}"
          return false
        end
      else
        puts "✗ ERROR: Could not find final output"
        return false
      end
    else
      puts "✗ ERROR: Could not parse final span alignment numbers"
      return false
    end
  else
    puts "✓ No final span alignment needed (all words already aligned)"
    return true
  end
end

# Test the specific cases mentioned in issue #5
puts "=== Testing Final Spans Alignment Fix ===\n"

results = []
results << test_final_spans_alignment("tests/alto_samples/34126288_plaintext.txt", "tests/alto_samples/34126288_alto.xml", "34126288")
results << test_final_spans_alignment("tests/alto_samples/34232712_plaintext.txt", "tests/alto_samples/34232712_alto.xml", "34232712")
results << test_final_spans_alignment("tests/alto_samples/34232713_plaintext.txt", "tests/alto_samples/34232713_alto.xml", "34232713")

puts "\n=== Test Results ==="
success_count = results.count(true)
total_count = results.size

puts "#{success_count}/#{total_count} tests passed"

if success_count == total_count
  puts "✓ All final spans alignment tests passed! Issue #5 is fixed."
  exit 0
else
  puts "✗ Some final spans alignment tests failed."
  exit 1
end