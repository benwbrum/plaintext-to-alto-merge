#!/usr/bin/env ruby

# Test script to verify the output functionality works as expected

require 'nokogiri'
require 'tempfile'

def test_output_to_file
  puts "Testing output to file..."
  
  # Create a temporary output file
  output_file = Tempfile.new(['test_output', '.xml'])
  output_path = output_file.path
  output_file.close
  
  begin
    # Run merge with output to file
    result = system("ruby merge.rb samples/33054-000002-0001.corrected.txt samples/33054-000002-0001.xml -o #{output_path}")
    
    unless result
      puts "✗ FAILURE: Command execution failed"
      return false
    end
    
    # Check if file exists and has content
    unless File.exist?(output_path) && File.size(output_path) > 0
      puts "✗ FAILURE: Output file not created or empty"
      return false
    end
    
    # Parse the output XML
    doc = Nokogiri::XML(File.read(output_path))
    
    # Check if it's valid XML
    if doc.errors.any?
      puts "✗ FAILURE: Output XML has parsing errors: #{doc.errors.join(', ')}"
      return false
    end
    
    # Check if Processing element exists
    processing = doc.at_xpath('//alto:Processing', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless processing
      puts "✗ FAILURE: Processing element not found in output"
      return false
    end
    
    # Check Processing element content
    software_name = processing.at_xpath('.//alto:softwareName', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless software_name&.content == 'plaintext-to-alto-merge'
      puts "✗ FAILURE: Incorrect softwareName in Processing element"
      return false
    end
    
    software_creator = processing.at_xpath('.//alto:softwareCreator', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless software_creator&.content == 'Brumfield Labs, LLC'
      puts "✗ FAILURE: Incorrect softwareCreator in Processing element"
      return false
    end
    
    app_description = processing.at_xpath('.//alto:applicationDescription', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless app_description&.content&.include?('https://github.com/benwbrum/plaintext-to-alto-merge')
      puts "✗ FAILURE: applicationDescription missing repository URL"
      return false
    end
    
    processing_datetime = processing.at_xpath('.//alto:processingDateTime', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless processing_datetime&.content&.match?(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      puts "✗ FAILURE: Invalid or missing processingDateTime"
      return false
    end
    
    # Check that original OCRProcessing element is preserved
    ocr_processing = doc.at_xpath('//alto:OCRProcessing', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
    unless ocr_processing
      puts "✗ FAILURE: Original OCRProcessing element not preserved"
      return false
    end
    
    puts "✓ SUCCESS: Output to file works correctly with Processing element"
    return true
    
  ensure
    # Clean up temporary file
    File.unlink(output_path) if File.exist?(output_path)
  end
end

def test_stdout_output
  puts "Testing output to stdout..."
  
  # Capture stdout
  output = `ruby merge.rb samples/33054-000002-0001.corrected.txt samples/33054-000002-0001.xml 2>/dev/null`
  
  if $?.exitstatus != 0
    puts "✗ FAILURE: Command execution failed"
    return false
  end
  
  # Check if output contains XML
  unless output.include?('<?xml') && output.include?('<alto')
    puts "✗ FAILURE: stdout output doesn't contain valid ALTO XML"
    return false
  end
  
  # Parse the output XML
  doc = Nokogiri::XML(output)
  
  # Check if it's valid XML
  if doc.errors.any?
    puts "✗ FAILURE: stdout XML has parsing errors: #{doc.errors.join(', ')}"
    return false
  end
  
  # Check if Processing element exists
  processing = doc.at_xpath('//alto:Processing', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
  unless processing
    puts "✗ FAILURE: Processing element not found in stdout output"
    return false
  end
  
  puts "✓ SUCCESS: Output to stdout works correctly"
  return true
end

def test_quality_mode_unchanged
  puts "Testing quality mode still works..."
  
  # Test quality mode output
  output = `ruby merge.rb -q samples/33054-000002-0001.corrected.txt samples/33054-000002-0001.xml 2>/dev/null`
  
  if $?.exitstatus != 0
    puts "✗ FAILURE: Quality mode command execution failed"
    return false
  end
  
  # Should only output percentage
  unless output.strip.match?(/^\d+\.\d+%$/)
    puts "✗ FAILURE: Quality mode output format incorrect: '#{output.strip}'"
    return false
  end
  
  puts "✓ SUCCESS: Quality mode unchanged"
  return true
end

# Run all tests
puts "=== Testing Output Functionality ===\n"

results = []
results << test_output_to_file
results << test_stdout_output  
results << test_quality_mode_unchanged

puts "\n=== Test Results ==="
success_count = results.count(true)
total_count = results.size

puts "#{success_count}/#{total_count} tests passed"

if success_count == total_count
  puts "✓ All output functionality tests passed!"
  exit 0
else
  puts "✗ Some tests failed."
  exit 1
end