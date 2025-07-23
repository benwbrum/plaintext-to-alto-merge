#!/usr/bin/env ruby

# Test script to verify that the script properly validates ALTO-XML files
# and handles invalid XML files gracefully

def test_invalid_xml_handling(corrected_file, invalid_xml_file)
  puts "Testing invalid XML handling for #{invalid_xml_file}"
  
  # Run the script with the invalid XML file
  output = `ruby merge.rb #{corrected_file} #{invalid_xml_file} 2>&1`
  exit_code = $?.exitstatus
  
  # Check that the script exits with error code 1
  if exit_code == 1
    # Check that the error message is appropriate
    if output.include?("Error: The provided XML file is not a valid ALTO-XML file")
      puts "✓ SUCCESS: Script correctly identifies invalid ALTO-XML and exits with proper error message"
      return true
    else
      puts "✗ FAILURE: Script exits with error but wrong message: '#{output.strip}'"
      return false
    end
  else
    puts "✗ FAILURE: Script should exit with code 1 but exited with code #{exit_code}"
    puts "Output: #{output.strip}"
    return false
  end
end

def test_valid_xml_handling(corrected_file, valid_xml_file)
  puts "Testing valid XML handling for #{valid_xml_file}"
  
  # Run the script with the valid XML file (just check it doesn't error on validation)
  output = `ruby merge.rb #{corrected_file} #{valid_xml_file} 2>&1`
  exit_code = $?.exitstatus
  
  # Check that the script doesn't fail due to validation error
  if exit_code == 0
    puts "✓ SUCCESS: Script correctly processes valid ALTO-XML file"
    return true
  elsif output.include?("Error: The provided XML file is not a valid ALTO-XML file")
    puts "✗ FAILURE: Script incorrectly rejects valid ALTO-XML file"
    puts "Output: #{output.strip}"
    return false
  else
    # The script may have other errors, but not validation errors - this is acceptable
    puts "✓ SUCCESS: Script correctly accepts valid ALTO-XML file (may have other processing issues)"
    return true
  end
end

# Test with the problematic file that caused the original issue
puts "=== Testing XML Validation ===\n"

results = []

# Test invalid XML (the error response file)
results << test_invalid_xml_handling(
  "alto_samples/cwrgm/34049765_plaintext.txt", 
  "alto_samples/cwrgm/34049765_alto.xml"
)

# Test valid XML
results << test_valid_xml_handling(
  "alto_samples/cwrgm/34047425_plaintext.txt", 
  "alto_samples/cwrgm/34047425_alto.xml"
)

puts "\n=== Test Results ==="
success_count = results.count(true)
total_count = results.size

puts "#{success_count}/#{total_count} tests passed"

if success_count == total_count
  puts "✓ All tests passed! XML validation works correctly."
  exit 0
else
  puts "✗ Some tests failed."
  exit 1
end