# plaintext-to-alto-merge
Exploratory code to merge corrected plaintext into a raw ALTO XML file, 
preserving bounding box info (as much as possible)


## Algorithm
This program will attempt to find matching lines in the ALTO and the corrected
plaintext, merge corrected text into matching lines, then remove "noise" lines 
from the ALTO file.

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
