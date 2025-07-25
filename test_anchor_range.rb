#!/usr/bin/env ruby

# Test to ensure anchors outside the expected ALTO range are handled gracefully

def test_anchor_range
  corrected_file = "alto_samples/cwrgm/34050462_plaintext.txt"
  alto_file = "alto_samples/cwrgm/34050462_alto.xml"

  output = `ruby merge.rb --quality #{corrected_file} #{alto_file} 2>&1`
  exit_code = $?.exitstatus

  if exit_code == 0 && output.strip.match(/^\d+\.\d+%$/)
    puts "\u2713 SUCCESS: Anchor out-of-range handled (#{output.strip})"
    exit 0
  else
    puts "\u2717 FAILURE: Unexpected output or exit code"
    puts output
    exit 1
  end
end

abort unless test_anchor_range
