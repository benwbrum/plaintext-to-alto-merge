#!/usr/bin/env ruby
require 'nokogiri'
require 'text'
require 'pry-byebug'

# TODO check for outliers via y-axis in coordinates instead of ordering
# TODO change to span-specific checks
# TODO change to passes by descending character order


LONG_WORD_LENGTH=3
LEVENSHTEIN_THRESHOLD=0.35  # Lowered from 0.45 to allow more matches

# TODO consider pruning punctuation to get semi-fuzzy matches


def unique_words_in_array(array)
  array.tally.select{|k,v| v==1}.keys  
end

def normalize_text(text)
  # Remove punctuation and convert to lowercase for better matching
  text.gsub(/[[:punct:]]/, '').downcase.strip
end

def calculate_word_distance(word1, word2)
  # Calculate normalized Levenshtein distance
  norm_word1 = normalize_text(word1)
  norm_word2 = normalize_text(word2)
  
  return 1.0 if norm_word1.empty? || norm_word2.empty?
  
  distance = Text::Levenshtein.distance(norm_word1, norm_word2)
  max_length = [norm_word1.length, norm_word2.length].max
  distance.to_f / max_length
end

def align_segments_dp(corrected_range, alto_range, start_range, alto_start)
  # Dynamic programming alignment for segments between anchors
  return if corrected_range.empty? || alto_range.empty?
  
  c_len = corrected_range.length
  a_len = alto_range.length
  
  # Create distance matrix
  dist = Array.new(c_len + 1) { Array.new(a_len + 1, Float::INFINITY) }
  path = Array.new(c_len + 1) { Array.new(a_len + 1) }
  
  # Initialize
  dist[0][0] = 0
  
  # Fill the matrix
  (0..c_len).each do |i|
    (0..a_len).each do |j|
      next if i == 0 && j == 0
      
      # Match/substitute
      if i > 0 && j > 0
        match_cost = calculate_word_distance(corrected_range[i-1], alto_range[j-1][:string])
        if dist[i-1][j-1] + match_cost < dist[i][j]
          dist[i][j] = dist[i-1][j-1] + match_cost
          path[i][j] = :match
        end
      end
      
      # Insert (skip corrected word) - higher cost to discourage skipping
      if i > 0 && dist[i-1][j] + 1.0 < dist[i][j]
        dist[i][j] = dist[i-1][j] + 1.0
        path[i][j] = :insert
      end
      
      # Delete (skip alto word) - higher cost to discourage skipping  
      if j > 0 && dist[i][j-1] + 1.0 < dist[i][j]
        dist[i][j] = dist[i][j-1] + 1.0
        path[i][j] = :delete
      end
    end
  end
  
  # Backtrack to find alignment
  i, j = c_len, a_len
  while i > 0 || j > 0
    case path[i][j]
    when :match
      # Use a more lenient threshold for DP alignment
      if calculate_word_distance(corrected_range[i-1], alto_range[j-1][:string]) < 0.6
        corrected_index = start_range + i - 1
        @alignment_map[corrected_index] = alto_range[j-1][:element]
      end
      i -= 1
      j -= 1
    when :insert
      i -= 1
    when :delete
      j -= 1
    else
      break
    end
  end
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
  print "remove_outliers removed #{removal_count} out-of-order elements\n"
end

Y_PROPORTION_THRESHOLD=0.15  # Increased from 0.1 to be less aggressive
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
  print "remove_outliers_by_y removed #{bad_ids.count} out-of-order elements\n"
end

def remove_outliers(alignment_map)
  remove_outliers_by_y(alignment_map)
end

def index_within_alto(element) 
  @alto_words.map{|e| e[:element]}.index(element)
end



def setup
  # Print usage information and exit if the -h option is present
  if ARGV.include?('-h')
    puts "Usage: merge.rb CORRECTED_FILE ALTO_FILE"
    exit
  end

  # Parse command line arguments
  @corrected_file = ARGV[0]
  @alto_file = ARGV[1]

  # Parse the ALTO-XML file using Nokogiri
  @alto_doc = Nokogiri::XML(File.read(@alto_file))

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
  unique_words = unique_words_of_size(corrected_range, shortest_word_length)
  # walk through each word, finding the index of the word within @corrected_words (start_range+i)
  unique_words.each do |candidate|
    # First try exact match
    alto_range_index = alto_range.index {|element| element[:string] == candidate}
    
    # If no exact match, try normalized match
    if !alto_range_index
      normalized_candidate = normalize_text(candidate)
      alto_range_index = alto_range.index {|element| normalize_text(element[:string]) == normalized_candidate}
    end

    if alto_range_index
      # associate words that are found if they do not violate word order
      corrected_index = corrected_range.index(candidate)+alignment_offset
      alto_words_index = alto_range_index + alto_offset
      @alignment_map[corrected_index] = alto_range[alto_range_index][:element]
    end
  end
end


def print_span_lengths
  print "Span lengths to resolve\n"
  old_key=nil
  @alignment_map.keys.sort.each_with_index do |key,i|
    if i>0 && key-old_key > 1
      print "#{i}\t#{key-old_key - 1}\t#\n"
    end
    old_key = key
  end
end

# read all the files and set up the models
setup

print "Phase A: Aligning words based on exact matches\n"
align_range(@corrected_words, @alto_words, 0, 0, 3)
remove_outliers(@alignment_map)

print "Pass 1 anchor count: #{@alignment_map.size}\t(#{(100 * @alignment_map.size.to_f/@corrected_words.size.to_f).floor}% aligned)\n"





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
  print "Pass #{pass_number} anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"
  ordered_ids= @alignment_map.sort.map{|a| a[1]['ID']}.join("\n")
#  print "Pass #{pass_number} ordered IDs:\n#{ordered_ids}\n\n"
end


print_span_lengths


print "Phase B: Aligning words based on fuzzy matching"
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
        fuzzy_match_array = long_words.map{|w| [w[:string], calculate_word_distance(candidate, w[:string])]}
        sorted_fuzzy_matches = fuzzy_match_array.sort{|a,b| a[1]<=>b[1]}
        best_match = sorted_fuzzy_matches.first
        if best_match && best_match[1] < LEVENSHTEIN_THRESHOLD
          # print "#{best_match[1].round(2)}\t#{candidate}\t#{best_match[0]}\n" if best_match[1] < 0.45
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
print "Phase B anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"
ordered_ids= @alignment_map.sort.map{|a| a[1]['ID']}.join("\n")

print_span_lengths

print "Phase B2: Dynamic programming alignment for remaining segments\n"
previous_index = nil
@alignment_map.keys.sort.each_with_index do |key,i|
  if i==0
    previous_index=key
  else
    current_index = key
    # get the range between the two
    start_range = previous_index+1
    end_range = current_index-1
    
    if end_range >= start_range
      corrected_range = @corrected_words[start_range..end_range]
      # get the range of @alto_words that corresponds to the current range
      alto_start = index_within_alto(@alignment_map[previous_index]) + 1
      alto_end = index_within_alto(@alignment_map[current_index]) - 1
      
      if alto_end >= alto_start
        alto_range = @alto_words[alto_start..alto_end]
        align_segments_dp(corrected_range, alto_range, start_range, alto_start)
      end
    end
    previous_index = key
  end
end

remove_outliers(@alignment_map)
print "Phase B2 anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"

print_span_lengths

print "Phase C: Final alignment and cleanup\n"
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

        print("#{corrected_range.count}\tA\t#{alto_range.map{|e| e[:string]}.join(' ')}\n\tC\t#{corrected_range.join(' ')}\n\n")
        if !alto_range.map{|e| e[:string]}.join('').match? /\S/
          print("WARNING: Misalignment at index #{current_index}.  Corrected text: #{corrected_range.join(' ')}\n")
        end
        if alto_range.count == corrected_range.count
          corrected_range.each_with_index do |candidate, range_index|
            corrected_index = range_index+start_range
            @alignment_map[corrected_index] = alto_range[range_index][:element]
          end
        else
          print("Unequal alignment #{corrected_range.count}::#{alto_range.count}:\n#{corrected_range.join(' ')}\ninto\n#{alto_range.map{|e| e[:string]}.join(' ')}\n\n")
          # Use dynamic programming for unequal segments instead of simple mapping
          if alto_range.size == 0
            print "WARNING: no range for #{corrected_range.join(' ')}\n"
          else
            # Use our DP alignment for these unequal segments
            align_segments_dp(corrected_range, alto_range, start_range, alto_start)
          end          
        end
      end
    end    
    previous_index=key 
  end
end

print "Alignment count after alignment by word count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"

print "Phase D: Handle initial and final segments\n"
# Handle initial segment
first_aligned_index = @alignment_map.keys.min
if first_aligned_index > 0
  # how many alto words precede the first aligned one?
  first_aligned_alto_element = @alignment_map[first_aligned_index]
  index_in_alto = @alto_words.map{|e| e[:element]}.index(@alignment_map[first_aligned_index])
  
  initial_corrected = @corrected_words[0..first_aligned_index-1]
  initial_alto = @alto_words[0..index_in_alto-1]
  
  if initial_corrected.size > 0 && initial_alto.size > 0
    align_segments_dp(initial_corrected, initial_alto, 0, 0)
  end
end

# Handle final segment
last_aligned_index = @alignment_map.keys.max
if last_aligned_index < @corrected_words.size-1
  # how many alto words follow the last aligned one?
  last_aligned_alto_element = @alignment_map[last_aligned_index]
  index_in_alto = @alto_words.map{|e| e[:element]}.index(@alignment_map[last_aligned_index])
  
  final_corrected = @corrected_words[last_aligned_index+1..-1]
  final_alto = @alto_words[index_in_alto+1..-1]
  
  if final_corrected.size > 0 && final_alto.size > 0
    align_segments_dp(final_corrected, final_alto, last_aligned_index+1, index_in_alto+1)
  end
end

print "Phase D anchor count: #{@alignment_map.size}\t(#{100 * @alignment_map.size.to_f/@corrected_words.size.to_f}% aligned)\n"

print "Phase E: Merging aligned words into ALTO-XML\n"
unaligned_corrected=[]
@corrected_words.each_with_index do |corrected,i|
  if @alignment_map[i]
    @alignment_map[i]['CONTENT'] = corrected
  else
    unaligned_corrected << [i,corrected]
  end
end

print "Phase F: Merging unaligned words into ALTO-XML\n"


print "Phase G: Remove unaligned XML elements\n"
aligned_elements = @alignment_map.values
@alto_words.each do |e|
  unless aligned_elements.include?(e[:element])
    @alto_doc.delete(e[:element])
  end
end

# Save the updated ALTO-XML file
#File.write(alto_file, alto_doc.to_xml)




# Known Issues

# Current problem:  mis-alignment that works forward, rather than backward, as in 202 (corrected) mapped to 206 (ALTO)
# This leaves significant gaps
# 199.upto(214) {|i| print "#{i}\t#{@corrected_words[i+1]}\t#{@alto_words[i][:string]}\n"}
BAD_ALGINMENT_DATA =<<EOF
199	appear	appear
200	to	to
201	occupy	occussy
202	a	as
203	space	face
204	of	of
205	about	about
206	4	a
207	miles	mile
208	in	as
209	a	as
210	NE	Not'
211	direction	direction.
212	From	From
213	Point	Point
214	Danger	danger
EOF


