#!/usr/bin/env ruby

# Test for Phase E unaligned words fix (Issue #13)
# Validates that unaligned corrected words are appended to closest ALTO elements

require 'nokogiri'
require 'tempfile'

def create_test_alto_xml
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <alto xmlns="http://www.loc.gov/standards/alto/ns-v4#">
      <Layout>
        <Page ID="PAGE1" HEIGHT="1000" WIDTH="1000">
          <PrintSpace ID="SPACE1" HPOS="0" VPOS="0" WIDTH="1000" HEIGHT="1000">
            <TextBlock ID="BLOCK1" HPOS="0" VPOS="0" WIDTH="1000" HEIGHT="1000">
              <TextLine ID="LINE1" HPOS="0" VPOS="0" WIDTH="1000" HEIGHT="100">
                <String ID="S1" CONTENT="apple" HPOS="0" VPOS="0" WIDTH="100" HEIGHT="100"/>
                <String ID="S2" CONTENT="banana" HPOS="100" VPOS="0" WIDTH="100" HEIGHT="100"/>
              </TextLine>
            </TextBlock>
          </PrintSpace>
        </Page>
      </Layout>
    </alto>
  XML
end

def create_test_corrected_text
  # This creates unaligned words: "red", "sweet", "yellow"
  <<~TEXT
    apple red banana sweet yellow
  TEXT
end

def test_unaligned_words_fix
  alto_file = Tempfile.new(['test_alto', '.xml'])
  corrected_file = Tempfile.new(['test_corrected', '.txt'])

  begin
    alto_file.write(create_test_alto_xml)
    alto_file.close
    
    corrected_file.write(create_test_corrected_text)
    corrected_file.close
    
    puts "=== Testing Phase E Unaligned Words Fix ==="
    puts "ALTO text: 'apple banana'"
    puts "Corrected text: 'apple red banana sweet yellow'"
    puts "Expected: 'red' appends to 'apple', 'sweet' and 'yellow' append to 'banana'"
    
    # Capture output
    output = `cd /home/runner/work/plaintext-to-alto-merge/plaintext-to-alto-merge && ruby merge.rb #{corrected_file.path} #{alto_file.path}`
    
    # Parse the final XML
    doc = Nokogiri::XML(output)
    
    s1_content = doc.at('String[@ID="S1"]')['CONTENT']
    s2_content = doc.at('String[@ID="S2"]')['CONTENT']
    
    puts "\nActual results:"
    puts "S1 (apple): '#{s1_content}'"
    puts "S2 (banana): '#{s2_content}'"
    
    # Validate expectations
    success = true
    
    if s1_content == "apple red"
      puts "✓ S1 correctly contains 'apple red'"
    else
      puts "✗ S1 expected 'apple red', got '#{s1_content}'"
      success = false
    end
    
    if s2_content == "banana sweet yellow"
      puts "✓ S2 correctly contains 'banana sweet yellow'"
    else
      puts "✗ S2 expected 'banana sweet yellow', got '#{s2_content}'"
      success = false
    end
    
    return success
    
  ensure
    alto_file.unlink
    corrected_file.unlink
  end
end

# Run the test
success = test_unaligned_words_fix

puts "\n=== Test Results ==="
if success
  puts "✓ Phase E unaligned words fix is working correctly!"
  exit 0
else
  puts "✗ Phase E unaligned words fix failed."
  exit 1
end