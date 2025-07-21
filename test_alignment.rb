#!/usr/bin/env ruby

# Simple test script to verify the alignment algorithm works as expected

def test_alignment(corrected_file, alto_file)
  puts "Testing alignment for #{corrected_file}"
  
  # Capture output and extract alignment rate using quality mode
  output = `ruby merge.rb --quality #{corrected_file} #{alto_file} 2>&1`
  
  # Find the final alignment rate (should be the last line with percentage)
  lines = output.split("\n")
  percentage_line = lines.last
  
  if percentage_line && percentage_line.match(/(\d+\.\d+)%/)
    alignment_percentage = percentage_line.match(/(\d+\.\d+)%/)[1].to_f
    puts "Final alignment rate: #{alignment_percentage}%"
    
    if alignment_percentage >= 95.0
      puts "✓ SUCCESS: Alignment rate meets target (>95%)"
      return true
    else
      puts "✗ FAILURE: Alignment rate below target (#{alignment_percentage}% < 95%)"
      return false
    end
  else
    puts "✗ ERROR: Could not find final alignment rate"
    return false
  end
end

# Test with both sample files
puts "=== Testing Alignment Algorithm ===\n"

results = []
results << test_alignment("samples/33054-000002-0001.corrected.txt", "samples/33054-000002-0001.xml")
results << test_alignment("llm/33054-000002-0001.corrected.txt", "samples/33054-000002-0001.xml")

puts "\n=== Test Results ==="
success_count = results.count(true)
total_count = results.size

puts "#{success_count}/#{total_count} tests passed"

if success_count == total_count
  puts "✓ All tests passed! Algorithm successfully improved alignment."
  exit 0
else
  puts "✗ Some tests failed."
  exit 1
end