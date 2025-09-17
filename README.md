# plaintext-to-alto-merge

A Ruby gem that merges corrected plaintext transcriptions into raw ALTO XML files, preserving bounding box information as much as possible.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'plaintext_to_alto_merge'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install plaintext_to_alto_merge

## Usage

### Command Line Interface

```bash
plaintext-to-alto-merge [options] CORRECTED_FILE ALTO_FILE
```

### Options
- `-v, --verbose`: Print debugging output
- `-q, --quality`: Print only final alignment percentages  
- `-o, --output FILE`: Output updated ALTO-XML to specified file (default: stdout)
- `-h, --help`: Show help message

### Examples

```bash
# Output to stdout
plaintext-to-alto-merge corrected.txt input.xml > output.xml

# Output to specific file
plaintext-to-alto-merge -o output.xml corrected.txt input.xml

# Get alignment quality percentage only
plaintext-to-alto-merge -q corrected.txt input.xml
```

### API Interface

#### Convenience Method

```ruby
require 'plaintext_to_alto_merge'

# Simple usage
result = PlaintextToAltoMerge.merge(
  corrected_text: "This is the corrected text...",
  alto_xml: "<alto>...</alto>",
  verbose: false
)

puts result  # Returns corrected ALTO XML as string
```

#### Class-based Approach

```ruby
require 'plaintext_to_alto_merge'

# Create merger instance
merger = PlaintextToAltoMerge::Merger.new(verbose: true)

# Process strings
result = merger.merge(
  corrected_text: corrected_text_string,
  alto_xml: alto_xml_string
)

# Or process files
result = merger.merge_files(
  corrected_file: "path/to/corrected.txt",
  alto_file: "path/to/input.xml"
)

# Get alignment statistics
puts "Alignment: #{merger.final_alignment_percentage.round(2)}%"
```

## Output

The updated ALTO-XML includes:
- Aligned text content from the corrected transcript
- Preserved bounding box information from the original ALTO
- A `Processing` element in the `Description` with metadata about this software


## Algorithm

This implementation is based on the **Recursive Text Alignment Scheme (RETAS)** described in Yalniz & Manmatha's paper ["A Fast Alignment Scheme for Automatic OCR Evaluation of Books"](https://ciir-publications.cs.umass.edu/getpdf.php?id=982).

### RETAS Overview

The RETAS algorithm provides a framework for aligning OCR-generated text with ground truth text by:
1. **Initial Anchor Points**: Finding exact word matches between texts to establish reliable alignment anchors
2. **Recursive Segmentation**: Recursively dividing the text into smaller segments between anchor points
3. **Local Alignment**: Aligning words within each segment using various strategies

### This Implementation

This program extends RETAS with several enhancements for merging corrected plaintext into ALTO XML while preserving bounding box information:

**Similarities to RETAS:**
- Uses exact word matching to establish initial anchor points
- Recursively processes segments between anchors
- Applies fuzzy matching for difficult-to-align segments

**Key Differences from RETAS:**
- **Multi-phase approach**: Implements distinct phases (A-F) with progressively more aggressive alignment strategies
- **ALTO-specific handling**: Preserves XML structure and bounding box coordinates from the original ALTO file
- **Enhanced fuzzy matching**: Uses Levenshtein distance with adaptive thresholds for different word lengths
- **Outlier removal**: Removes misaligned elements based on spatial coordinates (Y-axis positioning)
- **Word consolidation**: Handles cases where multiple corrected words map to single ALTO elements
- **Final cleanup**: Aggressive alignment phase for remaining unmatched words

The program will attempt to find matching words in the ALTO and the corrected
plaintext, merge corrected text into matching elements, then remove unaligned 
elements from the ALTO file.

### Merge Alto
Inputs:
* An ALTO file
* A plaintext file containing a corrected transcription of the OCR/HTR text

Outputs:
* An updated ALTO-XML file containing bounding boxes determined by the OCR/HTR 
process and text `CONTENT` from the corresponding corrected transcript

```ruby
doc = Nokogiri::XML(File.read(alto_filename))
corrected = File.readlines(plaintext_filename)

matching = match_lines(doc, corrected)

# for each Textline in the ALTO file, merge the matching line or delete it
match_index = 0
doc.search('Textline').each do |xml_line|
  if matching[match_index][0] == xml_line
    merge_lines(xml_line, matching[match_index][1])
    match_index += 1
  else
    doc.delete(xml_line)
  end
end
```

### Match Lines
Inputs:
* A DOM document representing an ALTO file
* An array of lines containing corrected transcription of the OCR/HTR text

Outputs:
* An array of tuples mapping `Textline` DOM nodes to strings representing 
corresponding lines

Pseudocode:


### Merge Lines
Inputs: 
* A `Textline` DOM element from the ALTO file
* A string containing plaintext of the line matching the Textline

Outputs:
* An `Textline` DOM element containing `String` elements which retain 
attributes except for `CONTENT`, which will contain a corresponding word 
from the updated text.


### Best Match Matrix
Inputs: 
* One string of corrected text (a line or word)
* An array of DOM elements to search

Outputs:
* A map contatining DOM elements with each element's distance from the string,
adjusted for string length

```ruby
def match_matrix(corrected_text, elements)
  matrix = {}
  # loop through each element, calculating the Levenshtein distance between 
  # the element and the corrected text
  elements.each do |element|
    # elements may be lines or words
    if element.name == 'Textline'
      # join the string contents together
      raw_text = element.search('String').map {|e| e['CONTENT']}.join
    else
      # this is a single word
      raw_text = element['CONTENT']
    end
    
    # eliminate any whitespace since word segmentation is a problem in OCR
    raw_text.gsub!(/\s/, '')
    correction = corrected_text.gsub(/\s/, '')

    # Find Levenshtein distance and normalize for length of text
    matrix[element] = Text::Levenshtein.distance(raw_text, correction) / raw_text.length
  end
end

### index_within_alto
This helper locates the position of an ALTO element within the cached
`@alto_words` array. It accepts an optional `range` argument so that
searches can be restricted to a subset of words. If the element is not
found within that range, the method returns `nil`.
