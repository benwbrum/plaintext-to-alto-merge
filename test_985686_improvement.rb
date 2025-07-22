#!/usr/bin/env ruby

# Test specifically for the 985686 file alignment improvement

def test_985686_alignment
  puts "Testing alignment improvement for 985686 file"
  
  # Test the current problematic file
  corrected_file = "tests/alto_samples/985686_plaintext.txt"
  alto_file = "tests/alto_samples/985686_alto.xml"
  
  # Capture output using quality mode to get just the percentage
  output = `ruby merge.rb --quality #{corrected_file} #{alto_file} 2>&1`
  
  # The output should just be the percentage
  if output.strip.match(/^(\d+\.\d+)%$/)
    alignment_percentage = $1.to_f
    puts "Current alignment rate: #{alignment_percentage}%"
    
    # Target improvement: from ~81.61% to at least 87%
    if alignment_percentage >= 87.0
      puts "✓ SUCCESS: Alignment rate improved significantly (#{alignment_percentage}% >= 87%)"
      return true
    else
      puts "✗ NEEDS IMPROVEMENT: Alignment rate still below target (#{alignment_percentage}% < 87%)"
      return false
    end
  else
    puts "✗ ERROR: Could not parse alignment rate from output: '#{output.strip}'"
    return false
  end
end

# Test to ensure we don't break other files
def test_baseline_performance
  puts "\nTesting baseline performance on other files..."
  
  # Test a few good performing files to ensure no regression
  test_files = [
    ["tests/alto_samples/34108828_plaintext.txt", "tests/alto_samples/34108828_alto.xml", 99.0],
    ["tests/alto_samples/985580_plaintext.txt", "tests/alto_samples/985580_alto.xml", 95.0],
    ["tests/alto_samples/985674_plaintext.txt", "tests/alto_samples/985674_alto.xml", 95.0]
  ]
  
  results = []
  test_files.each do |corrected_file, alto_file, min_expected|
    output = `ruby merge.rb --quality #{corrected_file} #{alto_file} 2>&1`
    
    if output.strip.match(/^(\d+\.\d+)%$/)
      alignment_percentage = $1.to_f
      file_name = File.basename(corrected_file, '_plaintext.txt')
      
      if alignment_percentage >= min_expected
        puts "✓ #{file_name}: #{alignment_percentage}% (>= #{min_expected}%)"
        results << true
      else
        puts "✗ #{file_name}: #{alignment_percentage}% (< #{min_expected}%) - REGRESSION!"
        results << false
      end
    else
      puts "✗ #{File.basename(corrected_file)}: Could not parse output"
      results << false
    end
  end
  
  return results.all?
end

puts "=== Testing 985686 Alignment Improvement ===\n"

# Run the tests
target_test = test_985686_alignment
baseline_test = test_baseline_performance

puts "\n=== Test Results ==="
if target_test && baseline_test
  puts "✓ All tests passed! The alignment improvement is successful."
  exit 0
else
  puts "✗ Some tests failed."
  puts "  Target improvement: #{target_test ? 'PASS' : 'FAIL'}"
  puts "  Baseline preservation: #{baseline_test ? 'PASS' : 'FAIL'}"
  exit 1
end