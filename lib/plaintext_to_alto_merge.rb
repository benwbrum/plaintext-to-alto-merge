# frozen_string_literal: true

require_relative "plaintext_to_alto_merge/version"
require_relative "plaintext_to_alto_merge/merger"

module PlaintextToAltoMerge
  class Error < StandardError; end
  
  # Convenience method for quick access
  def self.merge(corrected_text:, alto_xml:, verbose: false)
    merger = Merger.new(verbose: verbose)
    merger.merge(corrected_text: corrected_text, alto_xml: alto_xml, verbose: verbose)
  end
end
