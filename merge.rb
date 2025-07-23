#!/usr/bin/env ruby
require 'nokogiri'
require 'text'
# require 'pry-byebug'
require 'optparse'
require 'set'

# TODO check for outliers via y-axis in coordinates instead of ordering
# TODO change to span-specific checks
# TODO change to passes by descending character order


LONG_WORD_LENGTH=3
LEVENSHTEIN_THRESHOLD=0.45
# More lenient threshold for longer words in poor quality text
LEVENSHTEIN_THRESHOLD_LONG=0.60

# TODO consider pruning punctuation to get semi-fuzzy matches

# Global options
@verbose = false
@quality_only = false

# Conditional print function
def vprint(message)
  print message if @verbose
end

def is_valid_alto_xml?(doc)
  # Check if the root element is 'alto' or if it has ALTO namespace
  root = doc.root
  return false unless root
  
  # Check for ALTO root element or namespace
  if root.name == 'alto' || root.namespace&.href&.include?('alto')
    return true
  end
  
  # Alternative check: look for elements with CONTENT attributes (typical of ALTO)
  content_elements = doc.xpath('//*[@CONTENT]')
  return content_elements.size > 0
end


def unique_words_in_array(array)
  array.tally.select{|k,v| v==1}.keys  
end

# TODO use this!
def unique_words_of_size(array, size)
  unique_words_in_array(array.select { |word| word.size >= size })
end

def remove_outliers_by_id(alignment_map)
  # TODO -- make this more sophisticated; clean up
  # figure out standard deviation or use Y-axis coordinates of previous (and maybe next?) few words
  raw_ids = alignment_map.values.map{|e| e['ID']}
  ids = raw_ids.map{|id| id.sub('S','').to_i }
  sorted_ids = ids.sort
  differences = []
  removal_count = 0
  ids.each_with_index do |id,i|
    if i > 0
      difference = id - ids[i-1]
      differences << difference
      if difference.negative?
        # this element went down, so is probably an abberration
        alignment_map.delete_if {|k,v| v['ID'] == "S#{id}"}
        removal_count += 1
      end

    end
  end
  vprint "remove_outliers removed #{removal_count} out-of-order elements\n"
end

Y_PROPORTION_THRESHOLD=0.1
def remove_outliers_by_y(alignment_map)
  # TODO -- make this more sophisticated; clean up
  # figure out standard deviation or use Y-axis coordinates of previous (and maybe next?) few words
  y_map_raw = {}
  alignment_map.keys.sort.each {|i| y_map_raw[i] = alignment_map[i]['VPOS'].to_i }
  max_y=y_map_raw.values.max
  y_map={}
  y_map_raw.each{|k,v| y_map[k]=y_map_raw[k].to_f / max_y }
  y_deltas={}
  2.upto(y_map.size - 3) do |i|
    mean_y=(y_map.values[i-2..i-1].sum+y_map.values[i+1..i+2].sum) / 4
    delta_y = (mean_y - y_map.values[i]).abs
    y_deltas[y_map.keys[i]]=delta_y
  end


  removal_count = 0
  bad_ids = y_deltas.select{|k,v| v>Y_PROPORTION_THRESHOLD}.keys
  alignment_map.delete_if {|k,v| bad_ids.include? k}
  vprint "remove_outliers_by_y removed #{bad_ids.count} out-of-order elements\n"
end

def remove_outliers(alignment_map)
  remove_outliers_by_y(alignment_map)
end

def index_within_alto(element) 
  @alto_words.map{|e| e[:element]}.index(element)
end



def setup
  # Parse command line options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: merge.rb [options] CORRECTED_FILE ALTO_FILE"
    
    opts.on("-v", "--verbose", "Print debugging output") do |v|
      @verbose = v
    end
    
    opts.on("-q", "--quality", "Print only final alignment percentages") do |q|
      @quality_only = q
    end
    
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  # Check for required arguments
  if ARGV.length != 2
    puts "Error: Please provide both CORRECTED_FILE and ALTO_FILE"
    puts "Usage: merge.rb [options] CORRECTED_FILE ALTO_FILE"
    puts "Use -h or --help for more information"
    exit 1
  end

  # Parse command line arguments
  @corrected_file = ARGV[0]
  @alto_file = ARGV[1]

  # Parse the ALTO-XML file using Nokogiri
  @alto_doc = Nokogiri::XML(File.read(@alto_file))

  # Validate that this is a proper ALTO-XML file
  unless is_valid_alto_xml?(@alto_doc)
    puts "Error: The provided XML file is not a valid ALTO-XML file."
    puts "Expected ALTO-XML format with elements containing CONTENT attributes."
    puts "Found: #{@alto_doc.root.name if @alto_doc.root}" 
    exit 1
  end

  # create a hash of words we can use
  @alto_words = []
  @alto_doc.xpath('//*[@CONTENT]').each_with_index do |node,i|
    @alto_words[i] = {string: node['CONTENT'], element: node}
  end

  # Read the corrected text from the plaintext file
  corrected_text = File.read(@corrected_file)
  @corrected_words = corrected_text.split

  # map the index of each word to a corresponding node in the text
  @alignment_map = {}
end

def align_range(corrected_range, alto_range, alignment_offset, alto_offset, shortest_word_length=0)
  if alignment_offset == 0
    # For initial alignment, use unique words plus early duplicates
    unique_words = unique_words_of_size(corrected_range, shortest_word_length)
    
    # Find duplicate words that appear very early (first 10 words only)
    early_words = corrected_range.take(10).select { |word| word.size >= shortest_word_length }
    duplicate_early_words = early_words - unique_words
    
    # Combine unique words with early duplicates, but process unique words first
    words_to_process = unique_words + duplicate_early_words.uniq
    
    words_to_process.each do |candidate|
      # look for the word in the alto_range
      alto_range_index = alto_range.index {|element| element[:string] == candidate}

      if alto_range_index
        # For duplicates, only match if it's the first occurrence
        if duplicate_early_words.include?(candidate)
          corrected_index = corrected_range.index(candidate) + alignment_offset
        else
          corrected_index = corrected_range.index(candidate) + alignment_offset
        end
        alto_words_index = alto_range_index + alto_offset
        @alignment_map[corrected_index] = alto_range[alto_range_index][:element]
      end
    end
  else
    # For subsequent alignments, use unique words only
    unique_words = unique_words_of_size(corrected_range, shortest_word_length)
    # walk through each word, finding the index of the word within @corrected_words (start_range+i)
    unique_words.each do |candidate|
      # look for the word in the alto_range
      alto_range_index = alto_range.index {|element| element[:string] == candidate}

      if alto_range_index
        # associate words that are found if they do not violate word order
        corrected_index = corrected_range.index(candidate)+alignment_offset
        alto_words_index = alto_range_index + alto_offset
        @alignment_map[corrected_index] = alto_range[alto_range_index][:element]
      end
    end
  end
end


def print_alto_text(doc, alignment=true)
  vprint "Current ALTO XML text alignment:\n" if alignment
  doc.search('TextLine').each do |line|
    line.search('String').each do |string|
      if !alignment || @alignment_map.values.include?(string)
        vprint string['CONTENT']
      else
        vprint '___'
      end
      vprint ' '
    end
    vprint "\n"
  end 
  vprint "\n"
end

def print_span_lengths
  vprint "Span lengths to resolve\n"
  old_key=nil
  @alignment_map.keys.sort.each_with_index do |key,i|
    if i>0 && key-old_key > 1
      vprint "#{i}\t#{key-old_key - 1}\t#\n"
    end
    old_key = key
  end
end

# read all the files and set up the models
setup


vprint "Status before merge\n"
vprint "Plaintext contents:\n"
vprint File.read(@corrected_file)
vprint "\n\nALTO contents:\n"
print_alto_text(@alto_doc, false)
vprint "\n\n"
vprint "Phase A: Aligning words based on exact matches\n"
align_range(@corrected_words, @alto_words, 0, 0, 3)
remove_outliers(@alignment_map)

vprint "Pass 1 anchor count: #{@alignment_map.size}\t(#{(100 * @alignment_map.size.to_f/@corrected_words.size.to_f).floor}% aligned)\n"
print_alto_text(@alto_doc)





# now we have top-level segmentation matching unique words within the page.
# let's do the same for words within each range

pass_number=2
alignment_count = 0
while alignment_count < @alignment_map.size do
  alignment_count = @alignment_map.size
  pass_number += 1

  # false-positive matches are more likely with short words.  Attempting to align longer words first reduces the chances of misalignments.
  LONG_WORD_LENGTH.downto(0) do |shortest_word_length|
    previous_index = nil
    @alignment_map.keys.sort.each_with_index do |key,i|
      if i==0
        previous_index=key
      else
        current_index = key
        # get the range between the two
        start_range = previous_index+1
        end_range = current_index-1
        
        corrected_range = @corrected_words[start_range..end_range]
        # get the range of @alto_words that corresponds to the current range (segments within the anchors bounding the current range)

        alto_start = index_within_alto(@alignment_map[previous_index])
        alto_end = index_within_alto(@alignment_map[current_index])
        alto_range = @alto_words[alto_start..alto_end]

        align_range(corrected_range, alto_range, start_range, alto_start, shortest_word_length)

        previous_index=key
      end
    end
  end
  remove_outliers(@alignment_map)
  vprint "Pass #{pass_number} anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"
  ordered_ids= @alignment_map.sort.map{|a| a[1]['ID']}.join("\n")
#  print "Pass #{pass_number} ordered IDs:\n#{ordered_ids}\n\n"
end

print_alto_text(@alto_doc)

print_span_lengths


vprint "Phase B: Aligning words based on fuzzy matching"
previous_index = nil
@alignment_map.keys.sort.each_with_index do |key,i|
  if i==0
    previous_index=key
  else
    current_index = key
    # get the range between the two
    start_range = previous_index+1
    end_range = current_index-1
    
    corrected_range = @corrected_words[start_range..end_range]
    unique_words = unique_words_of_size(corrected_range, LONG_WORD_LENGTH)
    # get the range of @alto_words that corresponds to the current range (segments within the anchors bounding the current range)

    alto_start = index_within_alto(@alignment_map[previous_index])
    alto_end = index_within_alto(@alignment_map[current_index])
    alto_range = @alto_words[alto_start..alto_end]

    if alto_range.size > 0
      # walk through each word longer than three characters looking for close matches
      unique_words.each do |candidate|
        long_words = alto_range.select{|w| w[:string].length >=LONG_WORD_LENGTH}
        fuzzy_match_array = long_words.map{|w| [w[:string], Text::Levenshtein.distance(candidate, w[:string]).to_f/candidate.length]}
        sorted_fuzzy_matches = fuzzy_match_array.sort{|a,b| a[1]<=>b[1]}
        best_match = sorted_fuzzy_matches.first
        
        # Use more lenient threshold for longer words (likely more reliable matches)
        threshold = candidate.length >= 6 ? LEVENSHTEIN_THRESHOLD_LONG : LEVENSHTEIN_THRESHOLD
        
        if best_match && best_match[1] < threshold
          vprint "Fuzzy match: #{candidate} -> #{best_match[0]} (#{best_match[1].round(3)})\n" if @verbose
          alto_range_index = alto_range.index {|element| element[:string] == best_match[0]}
          corrected_index = corrected_range.index(candidate)+start_range
          alto_words_index = alto_range_index + alto_start
          @alignment_map[corrected_index] = alto_range[alto_range_index][:element]
        end
      end
    end
    previous_index=key
  end
end
remove_outliers(@alignment_map)
vprint "Phase B anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"
ordered_ids= @alignment_map.sort.map{|a| a[1]['ID']}.join("\n")

print_alto_text(@alto_doc)
print_span_lengths

vprint "Phase B2: Additional aggressive fuzzy matching for poor quality text\n"
# Try even more aggressive fuzzy matching for remaining unaligned words
previous_index = nil
@alignment_map.keys.sort.each_with_index do |key,i|
  if i==0
    previous_index=key
  else
    current_index = key
    # get the range between the two
    start_range = previous_index+1
    end_range = current_index-1
    
    corrected_range = @corrected_words[start_range..end_range]
    # Only process if there are still unaligned words in this range
    unaligned_in_range = corrected_range.select.with_index { |word, idx| !@alignment_map[start_range + idx] }
    
    if unaligned_in_range.any?
      alto_start = index_within_alto(@alignment_map[previous_index])
      alto_end = index_within_alto(@alignment_map[current_index])
      alto_range = @alto_words[alto_start..alto_end]
      
      if alto_range.size > 0
        # Try very aggressive fuzzy matching for remaining words
        unaligned_in_range.each do |candidate|
          next if candidate.length < 3  # Skip very short words
          
          corrected_index = corrected_range.index(candidate) + start_range
          next if @alignment_map[corrected_index]  # Skip if already aligned
          
          # Look at all ALTO words in range, not just unaligned ones
          all_alto_in_range = alto_range.select{|w| w[:string].length >= 2}
          fuzzy_match_array = all_alto_in_range.map{|w| [w[:string], Text::Levenshtein.distance(candidate, w[:string]).to_f/candidate.length]}
          sorted_fuzzy_matches = fuzzy_match_array.sort{|a,b| a[1]<=>b[1]}
          best_match = sorted_fuzzy_matches.first
          
          # Very aggressive threshold for poor quality text
          aggressive_threshold = 0.75
          
          if best_match && best_match[1] < aggressive_threshold
            # Check if this ALTO element is not already well-aligned to something else
            alto_element = alto_range.find {|w| w[:string] == best_match[0]}
            if alto_element && !@alignment_map.values.include?(alto_element[:element])
              @alignment_map[corrected_index] = alto_element[:element]
              vprint "Aggressive fuzzy match: #{candidate} -> #{best_match[0]} (#{best_match[1].round(3)})\n" if @verbose
            end
          end
        end
      end
    end
    previous_index=key
  end
end
remove_outliers(@alignment_map)
vprint "Phase B2 anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"

print_alto_text(@alto_doc)
print_span_lengths

vprint "Phase C: Aligning words based on word counts\n"
previous_index = nil
@alignment_map.keys.sort.each_with_index do |key,i|
  if i==0
    previous_index=key
  else
    current_index = key
    if current_index - previous_index == 1
      # null case -- no gap in mapping
    elsif current_index - previous_index == 2
      # simple case -- only one word has not been mapped
      missing_index = current_index - 1
      missing_alto = @alto_words.map{|e| e[:element]}.index(@alignment_map[previous_index])+1
      @alignment_map[missing_index] = @alto_words[missing_alto][:element]
    else
      # get the range between the two
      start_range = previous_index+1
      end_range = current_index-1
      if end_range - start_range > 0
        # TODO refactor range calculation
        corrected_range = @corrected_words[start_range..end_range]
        alto_start = @alto_words.map{|e| e[:element]}.index(@alignment_map[previous_index])+1
        alto_end = @alto_words.map{|e| e[:element]}.index(@alignment_map[current_index])-1

        alto_range = @alto_words[alto_start..alto_end]

        vprint("#{corrected_range.count}\tA\t#{alto_range.map{|e| e[:string]}.join(' ')}\n\tC\t#{corrected_range.join(' ')}\n\n")
        if !alto_range.map{|e| e[:string]}.join('').match? /\S/
          vprint("WARNING: Misalignment at index #{current_index}.  Corrected text: #{corrected_range.join(' ')}\n")
        end
        if alto_range.count == corrected_range.count
          corrected_range.each_with_index do |candidate, range_index|
            corrected_index = range_index+start_range
            @alignment_map[corrected_index] = alto_range[range_index][:element]
          end
        else
          vprint("Unequal alignment #{corrected_range.count}::#{alto_range.count}:\n#{corrected_range.join(' ')}\ninto\n#{alto_range.map{|e| e[:string]}.join(' ')}\n\n")
          # match each element with the corresponding one, then consolidate the last elements
          if alto_range.size==0
            # For missing spans, try to find nearest ALTO elements to interpolate
            vprint "WARNING: no range for #{corrected_range.join(' ')}\n"
            
            # Try to find ALTO elements around this span for potential mapping
            previous_alto_index = @alto_words.map{|e| e[:element]}.index(@alignment_map[previous_index])
            current_alto_index = @alto_words.map{|e| e[:element]}.index(@alignment_map[current_index])
            
            if previous_alto_index && current_alto_index && current_alto_index > previous_alto_index + 1
              # There are ALTO elements between the anchors, try to use them
              available_alto = @alto_words[(previous_alto_index + 1)..(current_alto_index - 1)]
              if available_alto.any?
                vprint "Found #{available_alto.size} available ALTO elements for interpolation\n"
                # Map as many corrected words as possible to available ALTO elements
                corrected_range.each_with_index do |candidate, range_index|
                  corrected_index = range_index + start_range
                  if range_index < available_alto.size
                    @alignment_map[corrected_index] = available_alto[range_index][:element]
                    vprint "Interpolated: #{candidate} -> #{available_alto[range_index][:string]}\n" if @verbose
                  end
                end
              end
            end
          else
            # Try to make intelligent partial alignments for unequal spans
            min_size = [corrected_range.size, alto_range.size].min
            max_size = [corrected_range.size, alto_range.size].max
            
            # If the difference is small (≤2), do one-to-one mapping for available pairs
            if max_size - min_size <= 2
              corrected_range.each_with_index do |candidate, range_index|
                corrected_index = range_index+start_range
                if range_index < alto_range.size
                  # map the corresponding index if within bounds
                  @alignment_map[corrected_index] = alto_range[range_index][:element]
                else
                  # For remaining corrected words, try to map to last available ALTO element
                  if alto_range.size > 0
                    @alignment_map[corrected_index] = alto_range[-1][:element]
                  end
                end
              end
            else
              # For larger differences, try fuzzy matching within the span
              corrected_range.each_with_index do |candidate, range_index|
                corrected_index = range_index+start_range
                if range_index < alto_range.size
                  # Direct mapping for initial words
                  @alignment_map[corrected_index] = alto_range[range_index][:element]
                else
                  # Try to find fuzzy matches for remaining words in the span
                  remaining_alto = alto_range[min_size..-1] || []
                  if remaining_alto.any?
                    fuzzy_matches = remaining_alto.map{|w| [w, Text::Levenshtein.distance(candidate, w[:string]).to_f/candidate.length]}
                    best_match = fuzzy_matches.min_by{|_, dist| dist}
                    if best_match && best_match[1] < LEVENSHTEIN_THRESHOLD_LONG
                      @alignment_map[corrected_index] = best_match[0][:element]
                      vprint "Span fuzzy match: #{candidate} -> #{best_match[0][:string]} (#{best_match[1].round(3)})\n" if @verbose
                    end
                  end
                end
              end
            end
          end          
        end
      end
    end    
    previous_index=key 
  end
end

# don't forget initial and final spans
first_aligned_index = @alignment_map.keys.min
if first_aligned_index > 0
  # how many alto words precede the first aligned one?
  first_aligned_alto_element = @alignment_map[first_aligned_index]
  index_in_alto = @alto_words.map{|e| e[:element]}.index(@alignment_map[first_aligned_index])
  
  # Get the ranges for initial spans
  corrected_range = @corrected_words[0..first_aligned_index-1]
  alto_range = @alto_words[0..index_in_alto-1]
  
  vprint "Initial span alignment: #{corrected_range.count} corrected words, #{alto_range.count} alto words\n"
  
  if index_in_alto == first_aligned_index
    # Equal counts - simple 1:1 mapping
    0.upto(index_in_alto-1) do |i|
      @alignment_map[i]=@alto_words[i][:element]
    end
  elsif alto_range.count > 0 && corrected_range.count > 0
    # Unequal counts - handle consolidation like medial spans
    vprint("Unequal initial alignment #{corrected_range.count}::#{alto_range.count}:\n#{corrected_range.join(' ')}\ninto\n#{alto_range.map{|e| e[:string]}.join(' ')}\n\n")
    
    corrected_range.each_with_index do |candidate, range_index|
      corrected_index = range_index
      if range_index < alto_range.size
        # map the corresponding index if within bounds
        @alignment_map[corrected_index] = alto_range[range_index][:element]
      else
        # this is beyond the ALTO elements; consolidate remaining corrected words into the last element
        @alignment_map[corrected_index] = alto_range.last[:element]
      end
    end
  elsif corrected_range.count > 0
    vprint "WARNING: #{corrected_range.count} initial corrected words have no corresponding ALTO words\n"
  end
end


last_aligned_index = @alignment_map.keys.max
if last_aligned_index < @corrected_words.size-1
  # how many alto words follow the last aligned one?
  last_aligned_alto_element = @alignment_map[last_aligned_index]
  last_alto_index = @alto_words.map{|e| e[:element]}.index(last_aligned_alto_element)
  
  # Calculate remaining words in both corrected text and ALTO
  remaining_corrected_words = @corrected_words.size - 1 - last_aligned_index
  remaining_alto_words = @alto_words.size - 1 - last_alto_index
  
  vprint "Final span alignment: #{remaining_corrected_words} corrected words, #{remaining_alto_words} alto words remaining\n"
  
  if remaining_alto_words > 0 && remaining_corrected_words > 0
    # Align remaining words if counts match or if we have enough ALTO words
    if remaining_alto_words == remaining_corrected_words
      # Perfect match - align one-to-one
      1.upto(remaining_corrected_words) do |i|
        corrected_index = last_aligned_index + i
        alto_index = last_alto_index + i
        @alignment_map[corrected_index] = @alto_words[alto_index][:element]
      end
    elsif remaining_alto_words >= remaining_corrected_words
      # More or equal ALTO words than corrected words - align first corrected words with first ALTO words
      1.upto(remaining_corrected_words) do |i|
        corrected_index = last_aligned_index + i
        alto_index = last_alto_index + i
        @alignment_map[corrected_index] = @alto_words[alto_index][:element]
      end
    else
      # Fewer ALTO words than corrected words - align as many as possible
      1.upto(remaining_alto_words) do |i|
        corrected_index = last_aligned_index + i
        alto_index = last_alto_index + i
        @alignment_map[corrected_index] = @alto_words[alto_index][:element]
      end
      vprint "WARNING: #{remaining_corrected_words - remaining_alto_words} final corrected words could not be aligned\n"
    end
  elsif remaining_corrected_words > 0
    vprint "WARNING: #{remaining_corrected_words} final corrected words have no corresponding ALTO words\n"
  end
end


print_alto_text(@alto_doc)
@final_alignment_percentage = 100 * @alignment_map.size.to_f/@corrected_words.size.to_f
vprint "Alignment count after alignment by word count: #{@alignment_map.size}\t(#{@final_alignment_percentage}% aligned)\n"

vprint "Phase D: Final aggressive alignment for remaining words\n"
# Try to align any remaining unaligned words by using available ALTO elements
unaligned_corrected_indices = (0...@corrected_words.size).select { |i| !@alignment_map[i] }
aligned_alto_elements = @alignment_map.values
unaligned_alto_elements = @alto_words.select { |w| !aligned_alto_elements.include?(w[:element]) }

vprint "Remaining unaligned: #{unaligned_corrected_indices.size} corrected words, #{unaligned_alto_elements.size} ALTO elements\n"

if unaligned_corrected_indices.any? && unaligned_alto_elements.any?
  # Try to match remaining words using position and fuzzy matching
  unaligned_corrected_indices.each do |corrected_index|
    candidate = @corrected_words[corrected_index]
    next if candidate.length < 3  # Skip very short words
    
    # Find best fuzzy match among remaining ALTO elements
    fuzzy_matches = unaligned_alto_elements.map do |alto_word|
      distance = Text::Levenshtein.distance(candidate, alto_word[:string]).to_f / candidate.length
      [alto_word, distance]
    end
    
    best_match = fuzzy_matches.min_by { |_, distance| distance }
    
    # Very generous threshold for final cleanup
    if best_match && best_match[1] < 0.85
      @alignment_map[corrected_index] = best_match[0][:element]
      unaligned_alto_elements.delete(best_match[0])
      vprint "Final alignment: #{candidate} -> #{best_match[0][:string]} (#{best_match[1].round(3)})\n" if @verbose
    end
  end
end

vprint "Final anchor count after aggressive alignment: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"
@final_alignment_percentage = 100 * @alignment_map.size.to_f/@corrected_words.size.to_f

vprint "Phase E: Merging aligned words into ALTO-XML\n"
unaligned_corrected=[]
@corrected_words.each_with_index do |corrected,i|
  if @alignment_map[i]
    @alignment_map[i]['CONTENT'] = corrected
  else
    unaligned_corrected << [i,corrected]
  end
end
print_alto_text(@alto_doc)

vprint "Phase E: Consolidating multiple corrected words into single ALTO elements\n"
# Group corrected words by their mapped ALTO element
alto_element_to_words = {}
@corrected_words.each_with_index do |corrected, i|
  if @alignment_map[i]
    alto_element = @alignment_map[i]
    alto_element_to_words[alto_element] ||= []
    alto_element_to_words[alto_element] << corrected
  else
    # Find the most recent previous aligned element and append unaligned word to it
    previous_aligned_index = nil
    (i-1).downto(0) do |j|
      if @alignment_map[j]
        previous_aligned_index = j
        break
      end
    end
    
    if previous_aligned_index
      # Append the unaligned word to the most recent previous aligned element
      previous_alto_element = @alignment_map[previous_aligned_index]
      alto_element_to_words[previous_alto_element] ||= []
      alto_element_to_words[previous_alto_element] << corrected
    end
    # If no previous aligned element exists, the word is not appended anywhere
  end
end

# Set CONTENT to concatenated words for each ALTO element
alto_element_to_words.each do |alto_element, words|
  alto_element['CONTENT'] = words.join(' ')
end

print_alto_text(@alto_doc)

vprint "Phase F: Remove unaligned XML elements"
aligned_elements = @alignment_map.values
@alto_words.each do |e|
  unless aligned_elements.include?(e[:element])
    @alto_doc.delete(e[:element])
  end
end
print_alto_text(@alto_doc)

# Output final alignment percentage if in quality mode
if @quality_only
  puts "#{@final_alignment_percentage.round(2)}%"
end

# Save the updated ALTO-XML file
#File.write(alto_file, alto_doc.to_xml)




