# frozen_string_literal: true

require 'nokogiri'
require 'text'
require 'time'

module PlaintextToAltoMerge
  class Merger
    LONG_WORD_LENGTH = 3
    LEVENSHTEIN_THRESHOLD = 0.45
    # More lenient threshold for longer words in poor quality text
    LEVENSHTEIN_THRESHOLD_LONG = 0.60

    attr_reader :final_alignment_percentage

    def initialize(verbose: false)
      @verbose = verbose
      @final_alignment_percentage = 0.0
    end

    # Main API method for programmatic use
    def merge(corrected_text:, alto_xml:, verbose: nil)
      @verbose = verbose unless verbose.nil?
      
      # Parse inputs
      @alto_doc = Nokogiri::XML(alto_xml)
      validate_alto_xml!(@alto_doc)
      
      # Parse corrected text (handle both string and array inputs)
      corrected_lines = corrected_text.is_a?(String) ? corrected_text.lines.map(&:chomp) : corrected_text
      @corrected_words = corrected_lines.join(' ').split

      # Initialize internal structures
      initialize_alto_words
      @alignment_map = {}

      # Run the alignment algorithm
      perform_alignment
      apply_alignment
      remove_unaligned_elements
      add_processing_element(@alto_doc)

      @alto_doc.to_xml(indent: 1, indent_text: "\t")
    end

    # Process files (for CLI compatibility)
    def merge_files(corrected_file:, alto_file:, verbose: nil)
      @verbose = verbose unless verbose.nil?
      
      corrected_text = File.read(corrected_file)
      alto_xml = File.read(alto_file)
      
      merge(corrected_text: corrected_text, alto_xml: alto_xml, verbose: @verbose)
    end

    private

    def vprint(message)
      print message if @verbose
    end

    def validate_alto_xml!(doc)
      unless is_valid_alto_xml?(doc)
        raise Error, "The provided XML is not a valid ALTO-XML file. Expected ALTO-XML format with elements containing CONTENT attributes. Found: #{doc.root&.name}"
      end
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

    def initialize_alto_words
      @alto_words = []
      @alto_doc.xpath('//*[@CONTENT]').each_with_index do |node, i|
        @alto_words[i] = { string: node['CONTENT'], element: node }
      end
    end

    def perform_alignment
      vprint "Phase A: Initial aggressive alignment\n"
      exact_matches = 0
      @corrected_words.each_with_index do |corrected, i|
        # Find exact matches first
        @alto_words.each_with_index do |alto_word, j|
          next if @alignment_map.values.include?(alto_word[:element])
          
          if corrected == alto_word[:string]
            @alignment_map[i] = alto_word[:element]
            exact_matches += 1
            vprint "Exact match: #{corrected}\n"
            break
          end
        end
      end
      vprint "Exact matches: #{exact_matches}\n"

      vprint "Phase B: Fuzzy alignment for unmatched words\n"
      unaligned_corrected = (0...@corrected_words.size).select { |i| !@alignment_map[i] }
      aligned_alto_elements = @alignment_map.values
      unaligned_alto_words = @alto_words.select { |w| !aligned_alto_elements.include?(w[:element]) }

      unaligned_corrected.each do |corrected_index|
        candidate = @corrected_words[corrected_index]
        next if candidate.length < LONG_WORD_LENGTH
        
        # Find fuzzy matches
        fuzzy_matches = unaligned_alto_words.map do |alto_word|
          distance = Text::Levenshtein.distance(candidate, alto_word[:string]).to_f / candidate.length
          [alto_word, distance]
        end
        
        best_match = fuzzy_matches.min_by { |_, distance| distance }
        threshold = candidate.length > LONG_WORD_LENGTH ? LEVENSHTEIN_THRESHOLD_LONG : LEVENSHTEIN_THRESHOLD
        
        if best_match && best_match[1] < threshold
          @alignment_map[corrected_index] = best_match[0][:element]
          unaligned_alto_words.delete(best_match[0])
          vprint "Fuzzy match: #{candidate} -> #{best_match[0][:string]} (#{best_match[1].round(3)})\n"
        end
      end

      vprint "Phase C: Positional alignment\n"
      # Additional phases can be added here if needed
      # For now, we'll use the basic alignment approach

      @final_alignment_percentage = 100 * @alignment_map.size.to_f / @corrected_words.size.to_f
      vprint "Final alignment: #{@alignment_map.size}/#{@corrected_words.size} words (#{@final_alignment_percentage.round(2)}%)\n"
    end

    def apply_alignment
      vprint "Phase E: Merging aligned words into ALTO-XML\n"
      unaligned_corrected = []
      @corrected_words.each_with_index do |corrected, i|
        if @alignment_map[i]
          @alignment_map[i]['CONTENT'] = corrected
        else
          unaligned_corrected << [i, corrected]
        end
      end

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
    end

    def remove_unaligned_elements
      vprint "Phase F: Remove unaligned XML elements\n"
      aligned_elements = @alignment_map.values
      @alto_words.each do |e|
        unless aligned_elements.include?(e[:element])
          e[:element].remove
        end
      end
    end

    def add_processing_element(doc)
      # Find the Description element
      description = doc.at_xpath('//alto:Description', 'alto' => 'http://www.loc.gov/standards/alto/ns-v4#')
      
      if description
        # Add a newline and tab before the Processing element
        description << Nokogiri::XML::Text.new("\n\t\t", doc)
        
        # Create the Processing element
        processing = Nokogiri::XML::Node.new('Processing', doc)
        processing['ID'] = 'plaintext-to-alto-merge-processing'
        
        # Create and add the processingDateTime element
        processing_date_time = Nokogiri::XML::Node.new('processingDateTime', doc)
        processing_date_time.content = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
        processing << processing_date_time
        
        # Create and add the processingSoftware element
        processing_software = Nokogiri::XML::Node.new('processingSoftware', doc)
        
        # Create softwareCreator element
        software_creator = Nokogiri::XML::Node.new('softwareCreator', doc)
        software_creator.content = 'plaintext-to-alto-merge'
        processing_software << software_creator
        
        # Create softwareName element
        software_name = Nokogiri::XML::Node.new('softwareName', doc)
        software_name.content = 'plaintext-to-alto-merge'
        processing_software << software_name
        
        # Create softwareVersion element
        software_version = Nokogiri::XML::Node.new('softwareVersion', doc)
        software_version.content = PlaintextToAltoMerge::VERSION
        processing_software << software_version
        
        processing << processing_software
        
        # Add the Processing element to Description
        description << processing
        
        # Add a final newline and tab after the Processing element
        description << Nokogiri::XML::Text.new("\n\t", doc)
        
        vprint "Added Processing element to ALTO-XML description\n"
      else
        vprint "Warning: Could not find Description element to add Processing info\n"
      end
    end
  end
end